.section __TEXT,__text,regular,pure_instructions
.align 4

// ARM64 Assembly implementation of visual_core.c
// Following the proven methodology from audio engine development

// Constants for floating point operations
.align 4
constants:
float_255:      .float 255.0
float_6:        .float 6.0
float_1:        .float 1.0
float_0:        .float 0.0

//==============================================================================
// uint32_t color_to_pixel(color_t color)
//
// Convert RGBA color struct to 32-bit ARGB pixel
// x0: pointer to color_t struct (r,g,b,a as uint8_t)
// Returns: 32-bit pixel in w0 (ARGB format)
//==============================================================================
.global _color_to_pixel
_color_to_pixel:
    // Load all 4 bytes from color struct
    ldr w1, [x0]              // Load r,g,b,a as 32-bit word
    
    // Extract individual bytes
    ubfx w2, w1, #0, #8       // r = bits 0-7
    ubfx w3, w1, #8, #8       // g = bits 8-15  
    ubfx w4, w1, #16, #8      // b = bits 16-23
    ubfx w5, w1, #24, #8      // a = bits 24-31
    
    // Pack into ARGB format: (a << 24) | (r << 16) | (g << 8) | b
    lsl w5, w5, #24           // a << 24
    lsl w2, w2, #16           // r << 16
    lsl w3, w3, #8            // g << 8
    // b stays as-is (w4)
    
    orr w0, w5, w2            // a | r
    orr w0, w0, w3            // (a | r) | g
    orr w0, w0, w4            // (a | r | g) | b
    
    ret

//==============================================================================
// visual_mode_t get_visual_mode(int bpm)
//
// Determine visual mode based on BPM
// w0: BPM value
// Returns: visual_mode_t enum value in w0
//==============================================================================
.global _get_visual_mode
_get_visual_mode:
    // if (bpm < 70) return VIS_MODE_THICK (0)
    cmp w0, #70
    mov w1, #0                // VIS_MODE_THICK = 0
    b.lt .Lgvm_return
    
    // if (bpm < 100) return VIS_MODE_RINGS (1)  
    cmp w0, #100
    mov w1, #1                // VIS_MODE_RINGS = 1
    b.lt .Lgvm_return
    
    // if (bpm < 130) return VIS_MODE_POLY (2)
    cmp w0, #130
    mov w1, #2                // VIS_MODE_POLY = 2
    b.lt .Lgvm_return
    
    // else return VIS_MODE_LISSA (3)
    mov w1, #3                // VIS_MODE_LISSA = 3

.Lgvm_return:
    mov w0, w1
    ret

//==============================================================================
// color_t hsv_to_rgb(hsv_t hsv)
//
// Convert HSV to RGB color (most complex function)
// x0: pointer to hsv_t struct (h,s,v as float)
// x1: pointer to output color_t struct
//==============================================================================
.global _hsv_to_rgb
_hsv_to_rgb:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp s8, s9, [sp, #16]     // Save callee-saved SIMD registers
    
    // Load HSV values
    ldr s0, [x0]              // h
    ldr s1, [x0, #4]          // s  
    ldr s2, [x0, #8]          // v
    
    // Save output pointer
    mov x2, x1
    
    // Load constants
    adrp x3, constants@PAGE
    add x3, x3, constants@PAGEOFF
    ldr s3, [x3, #12]         // float_0 = 0.0
    ldr s4, [x3, #8]          // float_1 = 1.0  
    ldr s5, [x3, #4]          // float_6 = 6.0
    ldr s6, [x3]              // float_255 = 255.0
    
    // Normalize hue to [0, 1) using fmod equivalent
    // Since we don't have fmod in ASM, we'll implement h = h - floor(h)
    fcvtzs w4, s0             // w4 = (int)h (floor for positive numbers)
    scvtf s7, w4              // s7 = (float)w4
    fsub s0, s0, s7           // h = h - floor(h)
    
    // Handle negative hue
    fcmp s0, s3               // compare h with 0.0
    fadd s8, s0, s4           // s8 = h + 1.0
    fcsel s0, s8, s0, lt      // if h < 0, h = h + 1.0, else h = h
    
    // Clamp saturation to [0, 1]
    fmax s1, s1, s3           // s = max(s, 0.0)
    fmin s1, s1, s4           // s = min(s, 1.0)
    
    // Clamp value to [0, 1]  
    fmax s2, s2, s3           // v = max(v, 0.0)
    fmin s2, s2, s4           // v = min(v, 1.0)
    
    // Calculate sector: i = (int)(h * 6.0)
    fmul s7, s0, s5           // s7 = h * 6.0
    fcvtzs w4, s7             // w4 = i = (int)(h * 6.0)
    
    // Calculate fractional part: f = h * 6.0 - i
    scvtf s8, w4              // s8 = (float)i
    fsub s8, s7, s8           // s8 = f = h * 6.0 - i
    
    // Calculate intermediate values
    fsub s9, s4, s1           // s9 = 1.0 - s
    fmul s9, s2, s9           // p = v * (1.0 - s)
    
    fmul s10, s8, s1          // s10 = f * s
    fsub s11, s4, s10         // s11 = 1.0 - f * s
    fmul s10, s2, s11         // q = v * (1.0 - f * s)
    
    fsub s11, s4, s8          // s11 = 1.0 - f
    fmul s11, s11, s1         // s11 = (1.0 - f) * s
    fsub s11, s4, s11         // s11 = 1.0 - (1.0 - f) * s
    fmul s11, s2, s11         // t = v * (1.0 - (1.0 - f) * s)
    
    // Switch on sector (i % 6)
    mov w5, #6
    udiv w6, w4, w5           // w6 = i / 6
    msub w4, w6, w5, w4       // w4 = i % 6
    
    // Jump table for switch statement
    adr x5, .Lswitch_table
    ldr w6, [x5, w4, uxtw #2] // Load offset for case w4
    add x5, x5, w6, sxtw      // Add offset to base
    br x5                     // Jump to case
    
.Lswitch_table:
    .word .Lcase0 - .Lswitch_table
    .word .Lcase1 - .Lswitch_table
    .word .Lcase2 - .Lswitch_table
    .word .Lcase3 - .Lswitch_table
    .word .Lcase4 - .Lswitch_table
    .word .Lcase5 - .Lswitch_table

.Lcase0:  // r = v, g = t, b = p
    fmov s12, s2              // r = v
    fmov s13, s11             // g = t
    fmov s14, s9              // b = p
    b .Lconvert_to_bytes

.Lcase1:  // r = q, g = v, b = p
    fmov s12, s10             // r = q
    fmov s13, s2              // g = v
    fmov s14, s9              // b = p
    b .Lconvert_to_bytes

.Lcase2:  // r = p, g = v, b = t
    fmov s12, s9              // r = p
    fmov s13, s2              // g = v
    fmov s14, s11             // b = t
    b .Lconvert_to_bytes

.Lcase3:  // r = p, g = q, b = v
    fmov s12, s9              // r = p
    fmov s13, s10             // g = q
    fmov s14, s2              // b = v
    b .Lconvert_to_bytes

.Lcase4:  // r = t, g = p, b = v
    fmov s12, s11             // r = t
    fmov s13, s9              // g = p
    fmov s14, s2              // b = v
    b .Lconvert_to_bytes

.Lcase5:  // r = v, g = p, b = q
    fmov s12, s2              // r = v
    fmov s13, s9              // g = p
    fmov s14, s10             // b = q
    
.Lconvert_to_bytes:
    // Convert float [0,1] to uint8 [0,255]
    fmul s12, s12, s6         // r *= 255.0
    fmul s13, s13, s6         // g *= 255.0  
    fmul s14, s14, s6         // b *= 255.0
    
    // Convert to integers and clamp
    fcvtns w4, s12            // r as int (nearest)
    fcvtns w5, s13            // g as int  
    fcvtns w6, s14            // b as int
    
    // Clamp to [0, 255]
    mov w7, #255
    cmp w4, #0
    csel w4, wzr, w4, lt      // r = max(r, 0)
    cmp w4, w7
    csel w4, w7, w4, gt       // r = min(r, 255)
    
    cmp w5, #0  
    csel w5, wzr, w5, lt      // g = max(g, 0)
    cmp w5, w7
    csel w5, w7, w5, gt       // g = min(g, 255)
    
    cmp w6, #0
    csel w6, wzr, w6, lt      // b = max(b, 0)
    cmp w6, w7
    csel w6, w7, w6, gt       // b = min(b, 255)
    
    // Pack into color_t struct and store
    strb w4, [x2]             // store r
    strb w5, [x2, #1]         // store g
    strb w6, [x2, #2]         // store b
    mov w7, #255
    strb w7, [x2, #3]         // store a = 255
    
    // Return the color struct (x0 already contains return pointer)
    mov x0, x2
    
    ldp s8, s9, [sp, #16]     // Restore callee-saved SIMD registers
    ldp x29, x30, [sp], #32
    ret
