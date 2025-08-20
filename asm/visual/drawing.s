
.section __TEXT,__text,regular,pure_instructions
.align 4

// ARM64 Assembly implementation of drawing.c
// Starting with simple functions following proven methodology

// Constants
.align 4
drawing_constants:
vis_width:      .word 800
vis_height:     .word 600

//==============================================================================
// static void set_pixel(uint32_t *pixels, int x, int y, uint32_t color)
//
// Set a pixel with bounds checking
// x0: pixels buffer pointer
// w1: x coordinate  
// w2: y coordinate
// w3: color (32-bit)
//==============================================================================
.global _set_pixel_asm
_set_pixel_asm:
    // Bounds check: x >= 0 && x < VIS_WIDTH
    cmp w1, #0
    b.lt .Lsp_return          // if x < 0, return
    cmp w1, #800              // VIS_WIDTH
    b.ge .Lsp_return          // if x >= 800, return
    
    // Bounds check: y >= 0 && y < VIS_HEIGHT  
    cmp w2, #0
    b.lt .Lsp_return          // if y < 0, return
    cmp w2, #600              // VIS_HEIGHT
    b.ge .Lsp_return          // if y >= 600, return
    
    // Calculate offset: pixels[y * VIS_WIDTH + x]
    mov w4, #800              // VIS_WIDTH
    mul w5, w2, w4            // y * VIS_WIDTH
    add w5, w5, w1            // y * VIS_WIDTH + x
    
    // Store color at calculated offset
    str w3, [x0, w5, uxtw #2] // pixels[offset] = color (4 bytes per pixel)
    
.Lsp_return:
    ret

//==============================================================================
// void clear_frame(uint32_t *pixels, uint32_t color)
//
// Clear entire frame buffer with specified color
// x0: pixels buffer pointer
// w1: color (32-bit)
//==============================================================================
.global _clear_frame_asm
_clear_frame_asm:
    // Calculate total pixels: VIS_WIDTH * VIS_HEIGHT = 800 * 600 = 480,000
    mov w2, #800              // VIS_WIDTH
    mov w3, #600              // VIS_HEIGHT  
    mul w2, w2, w3            // total pixels
    
    // Use NEON for faster clearing (process 4 pixels at a time)
    dup v0.4s, w1             // Duplicate color into 4 lanes
    
    // Main loop: clear 4 pixels at a time
    mov w3, #0                // counter
.Lcf_loop:
    cmp w3, w2                // compare counter with total
    b.ge .Lcf_done            // if counter >= total, done
    
    // Check if we can process 4 pixels safely
    sub w4, w2, w3            // remaining pixels
    cmp w4, #4
    b.lt .Lcf_single          // if less than 4 remaining, do single pixels
    
    // Store 4 pixels using NEON (calculate byte offset manually)
    lsl x4, x3, #2            // Convert pixel index to byte offset (64-bit)
    str q0, [x0, x4]          // Store 16 bytes (4 pixels)
    add w3, w3, #4            // increment counter by 4
    b .Lcf_loop
    
.Lcf_single:
    // Handle remaining pixels one by one
    cmp w3, w2
    b.ge .Lcf_done
    str w1, [x0, w3, uxtw #2] // Store single pixel
    add w3, w3, #1
    b .Lcf_single
    
.Lcf_done:
    ret

//==============================================================================
// void draw_circle_filled(uint32_t *pixels, int cx, int cy, int radius, uint32_t color)
//
// Draw a filled circle using simple algorithm
// x0: pixels buffer pointer
// w1: center x
// w2: center y  
// w3: radius
// w4: color
//==============================================================================
.global _draw_circle_filled_asm
_draw_circle_filled_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp w19, w20, [sp, #16]   // Save callee-saved registers
    stp w21, w22, [sp, #20]
    stp w23, w24, [sp, #24]
    
    // Save parameters
    mov x19, x0               // pixels
    mov w20, w1               // cx
    mov w21, w2               // cy
    mov w22, w3               // radius
    mov w23, w4               // color
    
    // Outer loop: y from -radius to +radius
    neg w24, w22              // y = -radius
    
.Ldcf_y_loop:
    cmp w24, w22              // compare y with radius
    b.gt .Ldcf_done           // if y > radius, done
    
    // Inner loop: x from -radius to +radius
    neg w25, w22              // x = -radius
    
.Ldcf_x_loop:
    cmp w25, w22              // compare x with radius
    b.gt .Ldcf_y_next         // if x > radius, next y
    
    // Check if point is inside circle: x*x + y*y <= radius*radius
    mul w26, w25, w25         // x * x
    mul w27, w24, w24         // y * y  
    add w26, w26, w27         // x*x + y*y
    mul w27, w22, w22         // radius * radius
    cmp w26, w27              // compare x*x + y*y with radius*radius
    b.gt .Ldcf_x_next         // if outside circle, skip
    
    // Point is inside circle, draw pixel
    add w1, w20, w25          // pixel_x = cx + x
    add w2, w21, w24          // pixel_y = cy + y
    mov x0, x19               // pixels buffer
    mov w3, w23               // color
    bl _set_pixel_asm         // call set_pixel_asm
    
.Ldcf_x_next:
    add w25, w25, #1          // x++
    b .Ldcf_x_loop
    
.Ldcf_y_next:
    add w24, w24, #1          // y++
    b .Ldcf_y_loop
    
.Ldcf_done:
    ldp w23, w24, [sp, #24]   // Restore callee-saved registers
    ldp w21, w22, [sp, #20]
    ldp w19, w20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// uint32_t circle_color(float base_hue, float saturation, float value)
//
// Helper function to create circle color with hue variation
// s0: base_hue
// s1: saturation
// s2: value
// Returns: color in w0
//==============================================================================
.global _circle_color_asm
_circle_color_asm:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    
    // Create HSV struct on stack at [sp, #16] (12 bytes: 3 floats)
    str s0, [sp, #16]         // h at [sp, #16]
    str s1, [sp, #20]         // s at [sp, #20] 
    str s2, [sp, #24]         // v at [sp, #24]
    
    // Call hsv_to_rgb
    add x0, sp, #16           // pointer to HSV struct on stack
    add x1, sp, #32           // pointer to output color_t on stack (4 bytes: r,g,b,a)
    bl _hsv_to_rgb            // Call the existing HSV to RGB function
    
    // Call color_to_pixel
    add x0, sp, #32           // pointer to color_t struct
    bl _color_to_pixel        // Call the existing color to pixel function
    
    // Return value already in w0
    ldp x29, x30, [sp], #48
    ret
