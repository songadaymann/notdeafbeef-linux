.arch armv8-a

// Glitch System ARM64 Assembly Implementation
// Based on glitch_system.c - Final visual component!

.section __DATA,__data
.align 3

// Character arrays for different glitch types
terrain_glitch_chars:
    .ascii "#=-%*+~^|\\/<>[]{}()\0"

shape_glitch_chars:
    .ascii "@#*+=-|\\/<>^~`'\".:;!?\0"

digital_noise_chars:
    .ascii "01234567890123456789abcdefABCDEF!@#$%^&*\0"

matrix_chars:
    .ascii "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*+-=\0"

// Glitch configuration structure
// typedef struct {
//     float terrain_glitch_rate;    // offset 0
//     float shape_glitch_rate;      // offset 4
//     float digital_noise_rate;     // offset 8
//     float glitch_intensity;       // offset 12
//     uint32_t glitch_seed;         // offset 16
// } glitch_config_t;
.align 2
glitch_config:
    .space 20, 0                  // 5 * 4 bytes = 20 bytes

glitch_initialized:
    .word 0                       // bool as 32-bit word

// Constants for glitch calculations
.align 2
.Lconst_0_1:
    .float 0.1
.Lconst_0_4:
    .float 0.4
.Lconst_0_05:
    .float 0.05
.Lconst_0_3:
    .float 0.3
.Lconst_10000_0:
    .float 10000.0
.Lconst_0_02:
    .float 0.02
.Lconst_decaf:
    .word 0xDECAF
.Lconst_lcg_mult:
    .word 1664525
.Lconst_lcg_add:
    .word 1013904223

.text

//==============================================================================
// init_glitch_system_asm
// Initialize glitch system with seed and intensity
// Input: w0 = seed (uint32_t), s0 = intensity (float)
// Output: None
//==============================================================================
.global _init_glitch_system_asm
_init_glitch_system_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Check if already initialized
    adrp x1, glitch_initialized@PAGE
    add x1, x1, glitch_initialized@PAGEOFF
    ldr w2, [x1]
    cbnz w2, .Ligs_return              // Return if already initialized
    
    // Set glitch_initialized = true
    mov w2, #1
    str w2, [x1]
    
    // Get pointer to glitch_config
    adrp x1, glitch_config@PAGE
    add x1, x1, glitch_config@PAGEOFF
    
    // Store glitch_intensity at offset 12
    str s0, [x1, #12]
    
    // Store glitch_seed at offset 16 (seed ^ 0xDECAF)
    adrp x2, .Lconst_decaf@PAGE
    add x2, x2, .Lconst_decaf@PAGEOFF
    ldr w2, [x2]
    eor w0, w0, w2
    str w0, [x1, #16]
    
    // Calculate terrain_glitch_rate = 0.1f + intensity * 0.4f
    adrp x2, .Lconst_0_1@PAGE
    add x2, x2, .Lconst_0_1@PAGEOFF
    ldr s1, [x2]                       // s1 = 0.1f
    adrp x2, .Lconst_0_4@PAGE
    add x2, x2, .Lconst_0_4@PAGEOFF
    ldr s2, [x2]                       // s2 = 0.4f
    fmul s3, s0, s2                    // s3 = intensity * 0.4f
    fadd s3, s1, s3                    // s3 = 0.1f + intensity * 0.4f
    str s3, [x1, #0]                   // store terrain_glitch_rate
    
    // Calculate shape_glitch_rate = 0.05f + intensity * 0.3f
    adrp x2, .Lconst_0_05@PAGE
    add x2, x2, .Lconst_0_05@PAGEOFF
    ldr s1, [x2]                       // s1 = 0.05f
    adrp x2, .Lconst_0_3@PAGE
    add x2, x2, .Lconst_0_3@PAGEOFF
    ldr s2, [x2]                       // s2 = 0.3f
    fmul s3, s0, s2                    // s3 = intensity * 0.3f
    fadd s3, s1, s3                    // s3 = 0.05f + intensity * 0.3f
    str s3, [x1, #4]                   // store shape_glitch_rate
    
    // Calculate digital_noise_rate = intensity * 0.1f
    fmul s1, s0, s1                    // s1 = intensity * 0.1f (reuse 0.1f from s1)
    adrp x2, .Lconst_0_1@PAGE
    add x2, x2, .Lconst_0_1@PAGEOFF
    ldr s2, [x2]                       // s2 = 0.1f
    fmul s1, s0, s2                    // s1 = intensity * 0.1f
    str s1, [x1, #8]                   // store digital_noise_rate
    
.Ligs_return:
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// get_glitch_random_asm
// Get pseudo-random value based on position and time
// Input: w0 = x, w1 = y, w2 = frame
// Output: w0 = random value
//==============================================================================
.global _get_glitch_random_asm
_get_glitch_random_asm:
    // Create hash = x * 73 + y * 37 + frame * 17
    mov w3, #73
    mul w3, w0, w3                     // w3 = x * 73
    mov w4, #37
    mul w4, w1, w4                     // w4 = y * 37
    add w3, w3, w4                     // w3 = x * 73 + y * 37
    mov w4, #17
    mul w4, w2, w4                     // w4 = frame * 17
    add w3, w3, w4                     // w3 = x * 73 + y * 37 + frame * 17
    
    // XOR with glitch_seed
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr w0, [x0, #16]                  // Load glitch_seed
    eor w3, w3, w0                     // hash ^= glitch_seed
    
    // Apply LCG: hash = hash * 1664525 + 1013904223
    adrp x0, .Lconst_lcg_mult@PAGE
    add x0, x0, .Lconst_lcg_mult@PAGEOFF
    ldr w0, [x0]                       // Load 1664525
    mul w3, w3, w0                     // hash *= 1664525
    adrp x0, .Lconst_lcg_add@PAGE
    add x0, x0, .Lconst_lcg_add@PAGEOFF
    ldr w0, [x0]                       // Load 1013904223
    add w0, w3, w0                     // hash += 1013904223
    
    ret

//==============================================================================
// get_glitched_terrain_char_asm
// Get glitched terrain character
// Input: w0 = original_char, w1 = x, w2 = y, w3 = frame
// Output: w0 = glitched character
//==============================================================================
.global _get_glitched_terrain_char_asm
_get_glitched_terrain_char_asm:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    
    // Save original character
    str w0, [sp, #16]
    
    // Check if glitch initialized
    adrp x0, glitch_initialized@PAGE
    add x0, x0, glitch_initialized@PAGEOFF
    ldr w0, [x0]
    cbz w0, .Lggtc_return_original
    
    // Call get_glitch_random(x, y, frame)
    mov w0, w1                         // x
    mov w1, w2                         // y
    mov w2, w3                         // frame
    bl _get_glitch_random_asm
    str w0, [sp, #20]                  // Save random value
    
    // Convert to float: rand_float = (rand_val % 10000) / 10000.0f
    mov w1, #10000
    udiv w2, w0, w1                    // w2 = rand_val / 10000
    msub w0, w2, w1, w0                // w0 = rand_val % 10000
    scvtf s0, w0                       // s0 = (float)(rand_val % 10000)
    adrp x0, .Lconst_10000_0@PAGE
    add x0, x0, .Lconst_10000_0@PAGEOFF
    ldr s1, [x0]                       // s1 = 10000.0f
    fdiv s0, s0, s1                    // s0 = rand_float
    
    // Compare with terrain_glitch_rate
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr s1, [x0]                       // Load terrain_glitch_rate
    fcmp s0, s1
    b.ge .Lggtc_return_original        // If rand_float >= glitch_rate, return original
    
    // Apply glitch: get character from terrain_glitch_chars
    ldr w0, [sp, #20]                  // Reload random value
    lsr w0, w0, #8                     // rand_val >> 8
    mov w1, #19                        // strlen(TERRAIN_GLITCH_CHARS) - 1
    udiv w2, w0, w1                    // w2 = (rand_val >> 8) / 19
    msub w0, w2, w1, w0                // w0 = (rand_val >> 8) % 19
    
    // Get character from array
    adrp x1, terrain_glitch_chars@PAGE
    add x1, x1, terrain_glitch_chars@PAGEOFF
    ldrb w0, [x1, w0, uxtw]           // Load character at index
    b .Lggtc_return
    
.Lggtc_return_original:
    ldr w0, [sp, #16]                  // Load original character

.Lggtc_return:
    ldp x29, x30, [sp], #48
    ret

//==============================================================================
// get_glitched_shape_char_asm
// Get glitched shape character
// Input: w0 = original_char, w1 = x, w2 = y, w3 = frame
// Output: w0 = glitched character
//==============================================================================
.global _get_glitched_shape_char_asm
_get_glitched_shape_char_asm:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    
    // Save original character
    str w0, [sp, #16]
    
    // Check if glitch initialized
    adrp x0, glitch_initialized@PAGE
    add x0, x0, glitch_initialized@PAGEOFF
    ldr w0, [x0]
    cbz w0, .Lggsc_return_original
    
    // Call get_glitch_random(x, y, frame)
    mov w0, w1                         // x
    mov w1, w2                         // y
    mov w2, w3                         // frame
    bl _get_glitch_random_asm
    str w0, [sp, #20]                  // Save random value
    
    // Convert to float: rand_float = (rand_val % 10000) / 10000.0f
    mov w1, #10000
    udiv w2, w0, w1                    // w2 = rand_val / 10000
    msub w0, w2, w1, w0                // w0 = rand_val % 10000
    scvtf s0, w0                       // s0 = (float)(rand_val % 10000)
    adrp x0, .Lconst_10000_0@PAGE
    add x0, x0, .Lconst_10000_0@PAGEOFF
    ldr s1, [x0]                       // s1 = 10000.0f
    fdiv s0, s0, s1                    // s0 = rand_float
    
    // Compare with shape_glitch_rate
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr s1, [x0, #4]                   // Load shape_glitch_rate
    fcmp s0, s1
    b.ge .Lggsc_return_original        // If rand_float >= glitch_rate, return original
    
    // Apply glitch: get character from shape_glitch_chars
    ldr w0, [sp, #20]                  // Reload random value
    lsr w0, w0, #8                     // rand_val >> 8
    mov w1, #21                        // strlen(SHAPE_GLITCH_CHARS) - 1
    udiv w2, w0, w1                    // w2 = (rand_val >> 8) / 21
    msub w0, w2, w1, w0                // w0 = (rand_val >> 8) % 21
    
    // Get character from array
    adrp x1, shape_glitch_chars@PAGE
    add x1, x1, shape_glitch_chars@PAGEOFF
    ldrb w0, [x1, w0, uxtw]           // Load character at index
    b .Lggsc_return
    
.Lggsc_return_original:
    ldr w0, [sp, #16]                  // Load original character

.Lggsc_return:
    ldp x29, x30, [sp], #48
    ret

//==============================================================================
// get_digital_noise_char_asm
// Get digital noise character
// Input: w0 = x, w1 = y, w2 = frame
// Output: w0 = noise character or space
//==============================================================================
.global _get_digital_noise_char_asm
_get_digital_noise_char_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Check if glitch initialized
    adrp x3, glitch_initialized@PAGE
    add x3, x3, glitch_initialized@PAGEOFF
    ldr w3, [x3]
    cbnz w3, .Lgdnc_initialized
    
    // Return space if not initialized
    mov w0, #32                        // ' ' character
    b .Lgdnc_return
    
.Lgdnc_initialized:
    // Call get_glitch_random(x, y, frame * 3)
    mov w3, #3
    mul w2, w2, w3                     // frame * 3
    bl _get_glitch_random_asm
    str w0, [sp, #16]                  // Save random value
    
    // Convert to float: rand_float = (rand_val % 10000) / 10000.0f
    mov w1, #10000
    udiv w2, w0, w1                    // w2 = rand_val / 10000
    msub w0, w2, w1, w0                // w0 = rand_val % 10000
    scvtf s0, w0                       // s0 = (float)(rand_val % 10000)
    adrp x0, .Lconst_10000_0@PAGE
    add x0, x0, .Lconst_10000_0@PAGEOFF
    ldr s1, [x0]                       // s1 = 10000.0f
    fdiv s0, s0, s1                    // s0 = rand_float
    
    // Compare with digital_noise_rate
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr s1, [x0, #8]                   // Load digital_noise_rate
    fcmp s0, s1
    b.ge .Lgdnc_return_space           // If rand_float >= noise_rate, return space
    
    // Apply noise: get character from digital_noise_chars
    ldr w0, [sp, #16]                  // Reload random value
    lsr w0, w0, #8                     // rand_val >> 8
    mov w1, #39                        // strlen(DIGITAL_NOISE_CHARS) - 1
    udiv w2, w0, w1                    // w2 = (rand_val >> 8) / 39
    msub w0, w2, w1, w0                // w0 = (rand_val >> 8) % 39
    
    // Get character from array
    adrp x1, digital_noise_chars@PAGE
    add x1, x1, digital_noise_chars@PAGEOFF
    ldrb w0, [x1, w0, uxtw]           // Load character at index
    b .Lgdnc_return
    
.Lgdnc_return_space:
    mov w0, #32                        // ' ' character

.Lgdnc_return:
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// should_apply_matrix_cascade_asm
// Check if matrix cascade should be applied
// Input: w0 = x, w1 = y, w2 = frame
// Output: w0 = 1 if should apply, 0 otherwise
//==============================================================================
.global _should_apply_matrix_cascade_asm
_should_apply_matrix_cascade_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Check if glitch initialized
    adrp x3, glitch_initialized@PAGE
    add x3, x3, glitch_initialized@PAGEOFF
    ldr w3, [x3]
    cbnz w3, .Lsamc_initialized
    
    // Return false if not initialized
    mov w0, #0
    b .Lsamc_return
    
.Lsamc_initialized:
    // Call get_glitch_random(x / 8, 0, frame / 10)
    lsr w0, w0, #3                     // x / 8
    mov w1, #0                         // y = 0 (column-based)
    mov w3, #10
    udiv w2, w2, w3                    // frame / 10
    bl _get_glitch_random_asm
    
    // Convert to float: rand_float = (rand_val % 10000) / 10000.0f
    mov w1, #10000
    udiv w2, w0, w1                    // w2 = rand_val / 10000
    msub w0, w2, w1, w0                // w0 = rand_val % 10000
    scvtf s0, w0                       // s0 = (float)(rand_val % 10000)
    adrp x0, .Lconst_10000_0@PAGE
    add x0, x0, .Lconst_10000_0@PAGEOFF
    ldr s1, [x0]                       // s1 = 10000.0f
    fdiv s0, s0, s1                    // s0 = rand_float
    
    // Calculate cascade_chance = 0.02f * glitch_intensity
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr s1, [x0, #12]                  // Load glitch_intensity
    adrp x0, .Lconst_0_02@PAGE
    add x0, x0, .Lconst_0_02@PAGEOFF
    ldr s2, [x0]                       // s2 = 0.02f
    fmul s1, s1, s2                    // s1 = 0.02f * glitch_intensity
    
    // Compare rand_float < cascade_chance
    fcmp s0, s1
    cset w0, lt                        // w0 = 1 if rand_float < cascade_chance, 0 otherwise

.Lsamc_return:
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// get_matrix_cascade_char_asm
// Get matrix cascade character
// Input: w0 = x, w1 = y, w2 = frame
// Output: w0 = cascade character
//==============================================================================
.global _get_matrix_cascade_char_asm
_get_matrix_cascade_char_asm:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Call get_glitch_random(x, y, frame)
    bl _get_glitch_random_asm
    
    // Get character from matrix_chars
    lsr w0, w0, #8                     // rand_val >> 8
    mov w1, #45                        // strlen(MATRIX_CHARS) - 1
    udiv w2, w0, w1                    // w2 = (rand_val >> 8) / 45
    msub w0, w2, w1, w0                // w0 = (rand_val >> 8) % 45
    
    // Get character from array
    adrp x1, matrix_chars@PAGE
    add x1, x1, matrix_chars@PAGEOFF
    ldrb w0, [x1, w0, uxtw]           // Load character at index
    
    ldp x29, x30, [sp], #16
    ret

//==============================================================================
// update_glitch_intensity_asm
// Update glitch intensity (can be driven by audio)
// Input: s0 = new_intensity (float)
// Output: None
//==============================================================================
.global _update_glitch_intensity_asm
_update_glitch_intensity_asm:
    // Check if glitch initialized
    adrp x0, glitch_initialized@PAGE
    add x0, x0, glitch_initialized@PAGEOFF
    ldr w0, [x0]
    cbz w0, .Lugi_return               // Return if not initialized
    
    // Get pointer to glitch_config
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    
    // Store new glitch_intensity at offset 12
    str s0, [x0, #12]
    
    // Calculate terrain_glitch_rate = 0.1f + new_intensity * 0.4f
    adrp x1, .Lconst_0_1@PAGE
    add x1, x1, .Lconst_0_1@PAGEOFF
    ldr s1, [x1]                       // s1 = 0.1f
    adrp x1, .Lconst_0_4@PAGE
    add x1, x1, .Lconst_0_4@PAGEOFF
    ldr s2, [x1]                       // s2 = 0.4f
    fmul s3, s0, s2                    // s3 = new_intensity * 0.4f
    fadd s3, s1, s3                    // s3 = 0.1f + new_intensity * 0.4f
    str s3, [x0, #0]                   // store terrain_glitch_rate
    
    // Calculate shape_glitch_rate = 0.05f + new_intensity * 0.3f
    adrp x1, .Lconst_0_05@PAGE
    add x1, x1, .Lconst_0_05@PAGEOFF
    ldr s1, [x1]                       // s1 = 0.05f
    adrp x1, .Lconst_0_3@PAGE
    add x1, x1, .Lconst_0_3@PAGEOFF
    ldr s2, [x1]                       // s2 = 0.3f
    fmul s3, s0, s2                    // s3 = new_intensity * 0.3f
    fadd s3, s1, s3                    // s3 = 0.05f + new_intensity * 0.3f
    str s3, [x0, #4]                   // store shape_glitch_rate
    
    // Calculate digital_noise_rate = new_intensity * 0.1f
    adrp x1, .Lconst_0_1@PAGE
    add x1, x1, .Lconst_0_1@PAGEOFF
    ldr s1, [x1]                       // s1 = 0.1f
    fmul s1, s0, s1                    // s1 = new_intensity * 0.1f
    str s1, [x0, #8]                   // store digital_noise_rate

.Lugi_return:
    ret

//==============================================================================
// get_glitch_intensity_asm
// Get current glitch intensity
// Input: None
// Output: s0 = glitch intensity (0.0 if not initialized)
//==============================================================================
.global _get_glitch_intensity_asm
_get_glitch_intensity_asm:
    // Check if glitch initialized
    adrp x0, glitch_initialized@PAGE
    add x0, x0, glitch_initialized@PAGEOFF
    ldr w0, [x0]
    cbnz w0, .Lggi_initialized
    
    // Return 0.0f if not initialized
    fmov s0, wzr
    b .Lggi_return
    
.Lggi_initialized:
    // Load and return glitch_intensity
    adrp x0, glitch_config@PAGE
    add x0, x0, glitch_config@PAGEOFF
    ldr s0, [x0, #12]                  // Load glitch_intensity

.Lggi_return:
    ret

//==============================================================================
// C-style wrapper exports (without _asm suffix) for integration with other ASM files
//==============================================================================

.global _get_glitched_terrain_char
_get_glitched_terrain_char:
    b _get_glitched_terrain_char_asm

.global _get_glitched_shape_char
_get_glitched_shape_char:
    b _get_glitched_shape_char_asm

.global _get_digital_noise_char
_get_digital_noise_char:
    b _get_digital_noise_char_asm

.global _should_apply_matrix_cascade
_should_apply_matrix_cascade:
    b _should_apply_matrix_cascade_asm

.global _get_matrix_cascade_char
_get_matrix_cascade_char:
    b _get_matrix_cascade_char_asm
