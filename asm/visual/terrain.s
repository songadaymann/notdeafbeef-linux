.section __TEXT,__text,regular,pure_instructions
.align 2

// External function declarations
.extern _draw_ascii_char_asm
.extern _hsv_to_rgb
.extern _color_to_pixel
.extern _get_glitched_terrain_char
.extern _get_digital_noise_char
.extern _should_apply_matrix_cascade
.extern _get_matrix_cascade_char
.extern _srand
.extern _rand

// Constants
#define TILE_SIZE 32
#define SCROLL_SPEED 2
#define TERRAIN_LENGTH 64
#define VIS_WIDTH 800
#define VIS_HEIGHT 600

// Terrain data structures
.section __DATA,__data
.align 5

// Terrain pattern array - 64 tiles * 8 bytes each = 512 bytes
// terrain_tile_t structure layout:
// - type: 4 bytes (terrain_type_t enum)
// - height: 4 bytes (int)
// Total: 8 bytes per terrain_tile_t
terrain_pattern:
    .space (64 * 8), 0      // TERRAIN_LENGTH * sizeof(terrain_tile_t)

// ASCII tile patterns - 32x32 = 1024 bytes each
tile_flat_pattern:
    .space (32 * 32), 0     // TILE_SIZE * TILE_SIZE

tile_slope_up_pattern:
    .space (32 * 32), 0     // TILE_SIZE * TILE_SIZE

tile_slope_down_pattern:
    .space (32 * 32), 0     // TILE_SIZE * TILE_SIZE

// Base hue for terrain color calculations
terrain_base_hue:
    .space 4, 0             // float

// Audio level for reactive effects
terrain_audio_level:
    .space 4, 0             // float

// Initialization flag
terrain_initialized:
    .space 1, 0             // bool

.section __TEXT,__text,regular,pure_instructions

// Generate deterministic terrain pattern (matching Python logic)
// static void generate_terrain_pattern(uint32_t seed)
// Input: w0 = seed
.global _generate_terrain_pattern_asm
_generate_terrain_pattern_asm:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str w0, [sp, #48]       // Save seed
    
    // Use XOR with magic number to match Python terrain_rng: seed ^ 0x7E44A1
    adr x1, .Lconst_magic
    ldr w1, [x1]            // Load 0x7E44A1
    eor w0, w0, w1          // seed ^ 0x7E44A1
    bl _srand
    
    // Get terrain pattern array pointer
    adrp x19, terrain_pattern@PAGE
    add x19, x19, terrain_pattern@PAGEOFF
    
    mov w20, #0             // i = 0
    
.Lgen_while_loop:
    cmp w20, #64            // TERRAIN_LENGTH = 64
    b.ge .Lgen_done
    
    // int feature_choice = rand() % 5
    bl _rand
    mov w1, #5
    udiv w2, w0, w1         // w2 = rand() / 5
    msub w21, w2, w1, w0    // w21 = feature_choice = rand() % 5
    
    cmp w21, #0             // feature_choice == 0 (flat)
    b.eq .Lgen_flat
    cmp w21, #1             // feature_choice == 1 (wall)
    b.eq .Lgen_wall
    cmp w21, #2             // feature_choice == 2 (slope_up)
    b.eq .Lgen_slope_up
    cmp w21, #3             // feature_choice == 3 (slope_down)
    b.eq .Lgen_slope_down
    b .Lgen_gap             // feature_choice == 4 (gap)
    
.Lgen_flat:
    // int length = 2 + (rand() % 5); // 2-6 tiles
    bl _rand
    mov w1, #5
    udiv w2, w0, w1
    msub w1, w2, w1, w0     // rand() % 5
    add w22, w1, #2         // length = 2 + (rand() % 5)
    
    // for (int j = 0; j < length && i < TERRAIN_LENGTH; j++, i++)
    mov w1, #0              // j = 0
.Lgen_flat_loop:
    cmp w1, w22             // j < length?
    b.ge .Lgen_while_loop
    cmp w20, #64            // i < TERRAIN_LENGTH?
    b.ge .Lgen_done
    
    // terrain_pattern[i] = {TERRAIN_FLAT, 2}
    mov w2, #8              // sizeof(terrain_tile_t) = 8
    mul w3, w20, w2         // i * 8
    add x3, x19, w3, uxtw   // &terrain_pattern[i]
    
    mov w2, #0              // TERRAIN_FLAT = 0
    str w2, [x3]            // store type
    mov w2, #2              // height = 2
    str w2, [x3, #4]        // store height
    
    add w1, w1, #1          // j++
    add w20, w20, #1        // i++
    b .Lgen_flat_loop
    
.Lgen_wall:
    // int wall_height = (rand() % 2) ? 4 : 6; // 4 or 6
    bl _rand
    mov w1, #2
    udiv w2, w0, w1
    msub w1, w2, w1, w0     // rand() % 2
    cmp w1, #0
    mov w1, #4              // Default to 4
    mov w2, #6              // Alternative 6
    csel w22, w2, w1, ne    // wall_height = (rand() % 2) ? 4 : 6
    
    // int wall_width = 2 + (rand() % 3); // 2-4
    bl _rand
    mov w1, #3
    udiv w2, w0, w1
    msub w1, w2, w1, w0     // rand() % 3
    add w1, w1, #2          // wall_width = 2 + (rand() % 3)
    
    // for (int j = 0; j < wall_width && i < TERRAIN_LENGTH; j++, i++)
    mov w2, #0              // j = 0
.Lgen_wall_loop:
    cmp w2, w1              // j < wall_width?
    b.ge .Lgen_while_loop
    cmp w20, #64            // i < TERRAIN_LENGTH?
    b.ge .Lgen_done
    
    // terrain_pattern[i] = {TERRAIN_WALL, wall_height}
    mov w3, #8              // sizeof(terrain_tile_t) = 8
    mul w4, w20, w3         // i * 8
    add x4, x19, w4, uxtw   // &terrain_pattern[i]
    
    mov w3, #1              // TERRAIN_WALL = 1
    str w3, [x4]            // store type
    str w22, [x4, #4]       // store wall_height
    
    add w2, w2, #1          // j++
    add w20, w20, #1        // i++
    b .Lgen_wall_loop
    
.Lgen_slope_up:
    // if (i < TERRAIN_LENGTH)
    cmp w20, #64
    b.ge .Lgen_while_loop
    
    // terrain_pattern[i++] = {TERRAIN_SLOPE_UP, 2}
    mov w1, #8              // sizeof(terrain_tile_t) = 8
    mul w2, w20, w1         // i * 8
    add x2, x19, w2, uxtw   // &terrain_pattern[i]
    
    mov w1, #2              // TERRAIN_SLOPE_UP = 2
    str w1, [x2]            // store type
    mov w1, #2              // height = 2
    str w1, [x2, #4]        // store height
    
    add w20, w20, #1        // i++
    
    // followed by elevated platform
    // int length = 2 + (rand() % 3); // 2-4
    bl _rand
    mov w1, #3
    udiv w2, w0, w1
    msub w1, w2, w1, w0     // rand() % 3
    add w22, w1, #2         // length = 2 + (rand() % 3)
    
    // for (int j = 0; j < length && i < TERRAIN_LENGTH; j++, i++)
    mov w1, #0              // j = 0
.Lgen_slope_up_platform_loop:
    cmp w1, w22             // j < length?
    b.ge .Lgen_while_loop
    cmp w20, #64            // i < TERRAIN_LENGTH?
    b.ge .Lgen_done
    
    // terrain_pattern[i] = {TERRAIN_FLAT, 3}
    mov w2, #8              // sizeof(terrain_tile_t) = 8
    mul w3, w20, w2         // i * 8
    add x3, x19, w3, uxtw   // &terrain_pattern[i]
    
    mov w2, #0              // TERRAIN_FLAT = 0
    str w2, [x3]            // store type
    mov w2, #3              // height = 3
    str w2, [x3, #4]        // store height
    
    add w1, w1, #1          // j++
    add w20, w20, #1        // i++
    b .Lgen_slope_up_platform_loop
    
.Lgen_slope_down:
    // if (i < TERRAIN_LENGTH)
    cmp w20, #64
    b.ge .Lgen_while_loop
    
    // terrain_pattern[i++] = {TERRAIN_SLOPE_DOWN, 3}
    mov w1, #8              // sizeof(terrain_tile_t) = 8
    mul w2, w20, w1         // i * 8
    add x2, x19, w2, uxtw   // &terrain_pattern[i]
    
    mov w1, #3              // TERRAIN_SLOPE_DOWN = 3
    str w1, [x2]            // store type
    mov w1, #3              // height = 3
    str w1, [x2, #4]        // store height
    
    add w20, w20, #1        // i++
    b .Lgen_while_loop
    
.Lgen_gap:
    // int length = 1 + (rand() % 2); // 1-2 tiles
    bl _rand
    mov w1, #2
    udiv w2, w0, w1
    msub w1, w2, w1, w0     // rand() % 2
    add w22, w1, #1         // length = 1 + (rand() % 2)
    
    // for (int j = 0; j < length && i < TERRAIN_LENGTH; j++, i++)
    mov w1, #0              // j = 0
.Lgen_gap_loop:
    cmp w1, w22             // j < length?
    b.ge .Lgen_while_loop
    cmp w20, #64            // i < TERRAIN_LENGTH?
    b.ge .Lgen_done
    
    // terrain_pattern[i] = {TERRAIN_GAP, 0}
    mov w2, #8              // sizeof(terrain_tile_t) = 8
    mul w3, w20, w2         // i * 8
    add x3, x19, w3, uxtw   // &terrain_pattern[i]
    
    mov w2, #4              // TERRAIN_GAP = 4
    str w2, [x3]            // store type
    mov w2, #0              // height = 0
    str w2, [x3, #4]        // store height
    
    add w1, w1, #1          // j++
    add w20, w20, #1        // i++
    b .Lgen_gap_loop
    
.Lgen_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Enhanced ASCII terrain character selection with audio reactivity
// static char get_enhanced_terrain_char(int x, int y, float audio_level, int frame)
// Input: w0 = x, w1 = y, s0 = audio_level, w2 = frame
// Output: w0 = character
.global _get_enhanced_terrain_char_asm
_get_enhanced_terrain_char_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str w2, [sp, #16]       // Save frame
    
    // int h = ((x * 13 + y * 7) ^ (x >> 3)) & 0xFF;
    mov w3, #13
    mul w3, w0, w3          // x * 13
    mov w4, #7
    mul w4, w1, w4          // y * 7
    add w3, w3, w4          // x * 13 + y * 7
    
    lsr w4, w0, #3          // x >> 3
    eor w3, w3, w4          // (x * 13 + y * 7) ^ (x >> 3)
    and w3, w3, #0xFF       // & 0xFF -> h
    
    // Audio-reactive density thresholds
    // Convert audio_level to int: audio_factor = (int)(audio_level * 100)
    adr x4, .Lconst_100
    ldr s1, [x4]            // 100.0f
    fmul s1, s0, s1         // audio_level * 100
    fcvtms w4, s1           // audio_factor
    
    // Modulate thresholds based on audio and frame
    ldr w5, [sp, #16]       // Load frame
    lsr w5, w5, #3          // frame >> 3 (slower cycling)
    add w4, w4, w5          // audio_factor + (frame >> 3)
    and w4, w4, #0x3F       // Keep in reasonable range
    
    // Dynamic thresholds: base + audio modulation
    mov w5, #40             // Base threshold 1
    add w5, w5, w4          // threshold1 = 40 + audio_factor
    mov w6, #120            // Base threshold 2  
    add w6, w6, w4          // threshold2 = 120 + audio_factor
    
    // Extended character set for more variety
    cmp w3, w5              // h < threshold1?
    b.ge .Lgt_check_mid
    
    // Dense characters - choose based on fine hash
    and w7, w3, #0x7        // w3 & 7 for 8 options
    cmp w7, #0
    b.ne .Lgt_dense_2
    mov w0, #'#'            // Solid block
    b .Lgt_done
.Lgt_dense_2:
    cmp w7, #1
    b.ne .Lgt_dense_3
    mov w0, #'@'            // Dense pattern
    b .Lgt_done
.Lgt_dense_3:
    cmp w7, #2
    b.ne .Lgt_dense_4
    mov w0, #'%'            // Medium-dense
    b .Lgt_done
.Lgt_dense_4:
    mov w0, #'*'            // Star pattern
    b .Lgt_done
    
.Lgt_check_mid:
    cmp w3, w6              // h < threshold2?
    b.ge .Lgt_sparse
    
    // Medium density characters
    and w7, w3, #0x7        // w3 & 7 for variety
    cmp w7, #0
    b.ne .Lgt_med_2
    mov w0, #'='            // Equal signs
    b .Lgt_done
.Lgt_med_2:
    cmp w7, #1
    b.ne .Lgt_med_3
    mov w0, #'+'            // Plus signs
    b .Lgt_done
.Lgt_med_3:
    cmp w7, #2
    b.ne .Lgt_med_4
    mov w0, #'~'            // Waves
    b .Lgt_done
.Lgt_med_4:
    mov w0, #':'            // Dots
    b .Lgt_done
    
.Lgt_sparse:
    // Sparse/light characters
    and w7, w3, #0x7        // w3 & 7 for variety
    cmp w7, #0
    b.ne .Lgt_sparse_2
    mov w0, #'-'            // Dashes
    b .Lgt_done
.Lgt_sparse_2:
    cmp w7, #1
    b.ne .Lgt_sparse_3
    mov w0, #'.'            // Periods
    b .Lgt_done
.Lgt_sparse_3:
    cmp w7, #2
    b.ne .Lgt_sparse_4
    mov w0, #','            // Commas
    b .Lgt_done
.Lgt_sparse_4:
    mov w0, #'_'            // Underscores
    
.Lgt_done:
    ldp x29, x30, [sp], #32
    ret

// Generate dynamic terrain color based on type, position, and audio
// uint32_t get_dynamic_terrain_color(terrain_type_t type, int x, int y, int frame, float audio_level)
// Input: w0 = terrain_type, w1 = x, w2 = y, w3 = frame, s0 = audio_level
// Output: w0 = color (ARGB)
.global _get_dynamic_terrain_color_asm
_get_dynamic_terrain_color_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp w0, w1, [sp, #16]   // Save type, x
    stp w2, w3, [sp, #24]   // Save y, frame
    str s0, [sp, #32]       // Save audio_level
    
    // Load base hue
    adrp x4, terrain_base_hue@PAGE
    add x4, x4, terrain_base_hue@PAGEOFF
    ldr s1, [x4]            // base_hue
    
    // Calculate hue variation based on terrain type
    mov w4, #0              // hue_offset = 0
    cmp w0, #0              // TERRAIN_FLAT
    b.eq .Lcolor_flat
    cmp w0, #1              // TERRAIN_WALL  
    b.eq .Lcolor_wall
    cmp w0, #2              // TERRAIN_SLOPE_UP
    b.eq .Lcolor_slope_up
    cmp w0, #3              // TERRAIN_SLOPE_DOWN
    b.eq .Lcolor_slope_down
    b .Lcolor_gap           // TERRAIN_GAP

.Lcolor_flat:
    // Flat terrain: base hue + position gradient
    ldr w1, [sp, #20]       // Load x
    mov w5, #800            // VIS_WIDTH
    scvtf s2, w1            // x as float
    scvtf s3, w5            // VIS_WIDTH as float
    fdiv s2, s2, s3         // x / VIS_WIDTH (0.0 to 1.0)
    adr x5, .Lconst_0_2
    ldr s3, [x5]            // 0.2f
    fmul s2, s2, s3         // position_offset = (x / VIS_WIDTH) * 0.2
    fadd s1, s1, s2         // hue = base_hue + position_offset
    b .Lcolor_calc_final

.Lcolor_wall:
    // Wall terrain: base hue + 0.6 (complementary) + audio reactive
    adr x5, .Lconst_0_6
    ldr s2, [x5]            // 0.6f
    fadd s1, s1, s2         // hue = base_hue + 0.6
    ldr s0, [sp, #32]       // Load audio_level
    adr x5, .Lconst_0_1
    ldr s2, [x5]            // 0.1f
    fmul s2, s0, s2         // audio_level * 0.1
    fadd s1, s1, s2         // hue += audio variation
    b .Lcolor_calc_final

.Lcolor_slope_up:
    // Slope up: base hue + 0.3 + frame cycling
    adr x5, .Lconst_0_3
    ldr s2, [x5]            // 0.3f
    fadd s1, s1, s2         // hue = base_hue + 0.3
    ldr w3, [sp, #28]       // Load frame
    scvtf s2, w3            // frame as float
    adr x5, .Lconst_1000
    ldr s3, [x5]            // 1000.0f
    fdiv s2, s2, s3         // frame / 1000
    adr x5, .Lconst_0_1
    ldr s3, [x5]            // 0.1f
    fmul s2, s2, s3         // (frame / 1000) * 0.1
    fadd s1, s1, s2         // hue += frame cycling
    b .Lcolor_calc_final

.Lcolor_slope_down:
    // Slope down: base hue + 0.8 + Y-based gradient
    adr x5, .Lconst_0_8
    ldr s2, [x5]            // 0.8f
    fadd s1, s1, s2         // hue = base_hue + 0.8
    ldr w2, [sp, #24]       // Load y
    scvtf s2, w2            // y as float
    adr x5, .Lconst_600
    ldr s3, [x5]            // 600.0f (VIS_HEIGHT)
    fdiv s2, s2, s3         // y / VIS_HEIGHT
    adr x5, .Lconst_0_15
    ldr s3, [x5]            // 0.15f
    fmul s2, s2, s3         // (y / VIS_HEIGHT) * 0.15
    fadd s1, s1, s2         // hue += y gradient
    b .Lcolor_calc_final

.Lcolor_gap:
    // Gap: Should not be rendered, but if it is, make it dark
    adr x5, .Lconst_0_5
    ldr s2, [x5]            // 0.5f
    fadd s1, s1, s2         // hue = base_hue + 0.5
    
.Lcolor_calc_final:
    // Normalize hue to 0.0-1.0 range: fmod(hue, 1.0)
    adr x5, .Lconst_1_0
    ldr s2, [x5]            // 1.0f
    fdiv s3, s1, s2         // hue / 1.0
    fcvtms w4, s3           // floor(hue / 1.0)
    scvtf s3, w4            // floor as float
    fmsub s1, s3, s2, s1    // hue = hue - floor * 1.0 (fmod)
    
    // Calculate saturation: base 0.9 + audio variation
    adr x5, .Lconst_0_9
    ldr s2, [x5]            // 0.9f base saturation
    ldr s0, [sp, #32]       // Load audio_level
    adr x5, .Lconst_0_1
    ldr s3, [x5]            // 0.1f
    fmul s3, s0, s3         // audio_level * 0.1
    fadd s2, s2, s3         // saturation = 0.9 + audio variation
    
    // Clamp saturation to 1.0 max
    adr x5, .Lconst_1_0
    ldr s3, [x5]            // 1.0f
    fmin s2, s2, s3         // saturation = min(saturation, 1.0)
    
    // Calculate brightness: base 0.8 + audio variation
    adr x5, .Lconst_0_8
    ldr s3, [x5]            // 0.8f base brightness
    ldr s0, [sp, #32]       // Load audio_level
    adr x5, .Lconst_0_2
    ldr s4, [x5]            // 0.2f
    fmul s4, s0, s4         // audio_level * 0.2
    fadd s3, s3, s4         // brightness = 0.8 + audio variation
    
    // Clamp brightness to 1.0 max
    adr x5, .Lconst_1_0
    ldr s4, [x5]            // 1.0f
    fmin s3, s3, s4         // brightness = min(brightness, 1.0)
    
    // Create HSV struct on stack: {h, s, v}
    str s1, [sp, #40]       // h
    str s2, [sp, #44]       // s
    str s3, [sp, #48]       // v
    
    // Convert HSV to RGB and then to pixel
    add x0, sp, #40         // HSV struct pointer
    add x1, sp, #52         // RGB output buffer
    bl _hsv_to_rgb
    
    // Convert RGB to pixel
    add x0, sp, #52         // RGB struct pointer
    bl _color_to_pixel
    
    // Return color in w0
    ldp x29, x30, [sp], #96
    ret

// Build procedural ASCII tile pattern with enhanced character selection
// static void build_ascii_tile_pattern(char *tile_pattern)
// Input: x0 = tile_pattern pointer
.global _build_ascii_tile_pattern_asm
_build_ascii_tile_pattern_asm:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    
    mov x19, x0             // tile_pattern pointer
    mov w20, #0             // y = 0
    
.Lbatp_y_loop:
    cmp w20, #32            // TILE_SIZE = 32
    b.ge .Lbatp_done
    
    mov w21, #0             // x = 0
    
.Lbatp_x_loop:
    cmp w21, #32            // TILE_SIZE = 32
    b.ge .Lbatp_next_y
    
    // char c = get_enhanced_terrain_char(x, y, audio_level, frame)
    mov w0, w21             // x
    mov w1, w20             // y
    // Load audio level (default to 0.5 for tile building)
    adr x2, .Lconst_0_5
    ldr s0, [x2]            // audio_level = 0.5
    mov w2, #0              // frame = 0 for static patterns
    bl _get_enhanced_terrain_char_asm
    
    // tile_pattern[y * TILE_SIZE + x] = c
    mov w1, #32             // TILE_SIZE
    mul w2, w20, w1         // y * TILE_SIZE
    add w2, w2, w21         // y * TILE_SIZE + x
    strb w0, [x19, w2, uxtw] // Store character
    
    add w21, w21, #1        // x++
    b .Lbatp_x_loop
    
.Lbatp_next_y:
    add w20, w20, #1        // y++
    b .Lbatp_y_loop
    
.Lbatp_done:
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Build ASCII slope tile pattern (45 degree angle)
// static void build_ascii_slope_pattern(char *tile_pattern, bool slope_up)
// Input: x0 = tile_pattern pointer, w1 = slope_up (bool)
.global _build_ascii_slope_pattern_asm
_build_ascii_slope_pattern_asm:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str w23, [sp, #48]
    
    mov x19, x0             // tile_pattern pointer
    mov w23, w1             // slope_up flag
    
    // Initialize to space (transparent): memset(tile_pattern, ' ', TILE_SIZE * TILE_SIZE)
    mov w1, #' '            // space character
    mov w2, #1024           // TILE_SIZE * TILE_SIZE = 32 * 32 = 1024
    
.Lbasp_memset_loop:
    cmp w2, #0
    b.le .Lbasp_memset_done
    sub w2, w2, #1
    strb w1, [x19, w2, uxtw]
    b .Lbasp_memset_loop
    
.Lbasp_memset_done:
    mov w20, #0             // y = 0
    
.Lbasp_y_loop:
    cmp w20, #32            // TILE_SIZE = 32
    b.ge .Lbasp_done
    
    mov w21, #0             // x = 0
    
.Lbasp_x_loop:
    cmp w21, #32            // TILE_SIZE = 32
    b.ge .Lbasp_next_y
    
    // int threshold = slope_up ? x : (TILE_SIZE - x)
    cmp w23, #0             // slope_up?
    b.eq .Lbasp_slope_down
    mov w22, w21            // threshold = x
    b .Lbasp_check_threshold
    
.Lbasp_slope_down:
    mov w22, #32            // TILE_SIZE = 32
    sub w22, w22, w21       // threshold = TILE_SIZE - x
    
.Lbasp_check_threshold:
    // if (y > threshold)
    cmp w20, w22
    b.le .Lbasp_next_x      // Skip if y <= threshold
    
    // Below slope - use enhanced terrain character  
    mov w0, w21             // x
    mov w1, w20             // y
    // Load audio level (default to 0.5 for tile building)
    adr x2, .Lconst_0_5
    ldr s0, [x2]            // audio_level = 0.5
    mov w2, #0              // frame = 0 for static patterns
    bl _get_enhanced_terrain_char_asm
    
    // tile_pattern[y * TILE_SIZE + x] = c
    mov w1, #32             // TILE_SIZE
    mul w2, w20, w1         // y * TILE_SIZE
    add w2, w2, w21         // y * TILE_SIZE + x
    strb w0, [x19, w2, uxtw] // Store character
    
.Lbasp_next_x:
    add w21, w21, #1        // x++
    b .Lbasp_x_loop
    
.Lbasp_next_y:
    add w20, w20, #1        // y++
    b .Lbasp_y_loop
    
.Lbasp_done:
    ldr w23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// Initialize terrain system
// void init_terrain(uint32_t seed, float base_hue)
// Input: w0 = seed, s0 = base_hue
.global _init_terrain_asm
_init_terrain_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str w0, [sp, #32]       // Save seed
    str s0, [sp, #36]       // Save base_hue
    
    // Check if already initialized
    adrp x0, terrain_initialized@PAGE
    add x0, x0, terrain_initialized@PAGEOFF
    ldrb w1, [x0]
    cmp w1, #0
    b.ne .Linit_terrain_done // Return if already initialized
    
    // generate_terrain_pattern(seed)
    ldr w0, [sp, #32]       // Load seed
    bl _generate_terrain_pattern_asm
    
    // Store base hue for dynamic color calculations
    ldr s0, [sp, #36]       // Load base_hue
    adrp x0, terrain_base_hue@PAGE
    add x0, x0, terrain_base_hue@PAGEOFF
    str s0, [x0]            // terrain_base_hue = base_hue
    
    // Build ASCII tile patterns
    // build_ascii_tile_pattern(tile_flat_pattern)
    adrp x0, tile_flat_pattern@PAGE
    add x0, x0, tile_flat_pattern@PAGEOFF
    bl _build_ascii_tile_pattern_asm
    
    // build_ascii_slope_pattern(tile_slope_up_pattern, true)
    adrp x0, tile_slope_up_pattern@PAGE
    add x0, x0, tile_slope_up_pattern@PAGEOFF
    mov w1, #1              // true
    bl _build_ascii_slope_pattern_asm
    
    // build_ascii_slope_pattern(tile_slope_down_pattern, false)
    adrp x0, tile_slope_down_pattern@PAGE
    add x0, x0, tile_slope_down_pattern@PAGEOFF
    mov w1, #0              // false
    bl _build_ascii_slope_pattern_asm
    
    // Set initialized flag
    adrp x0, terrain_initialized@PAGE
    add x0, x0, terrain_initialized@PAGEOFF
    mov w1, #1
    strb w1, [x0]           // terrain_initialized = true
    
.Linit_terrain_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// Update terrain audio level for reactive effects
// void update_terrain_audio_level(float audio_level)
// Input: s0 = audio_level
.global _update_terrain_audio_level_asm
_update_terrain_audio_level_asm:
    adrp x0, terrain_audio_level@PAGE
    add x0, x0, terrain_audio_level@PAGEOFF
    str s0, [x0]            // terrain_audio_level = audio_level
    ret

// Enhanced terrain drawing with dynamic colors and audio reactivity
// void draw_terrain_enhanced(uint32_t *pixels, int frame, float audio_level)
// Input: x0 = pixels, w1 = frame, s0 = audio_level
.global _draw_terrain_enhanced_asm
_draw_terrain_enhanced_asm:
    stp x29, x30, [sp, #-160]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    mov x19, x0             // pixels
    mov w20, w1             // frame
    str s0, [sp, #96]       // Save audio_level
    
    // Update terrain audio level
    adrp x0, terrain_audio_level@PAGE
    add x0, x0, terrain_audio_level@PAGEOFF
    str s0, [x0]            // terrain_audio_level = audio_level
    
    // Check if initialized
    adrp x0, terrain_initialized@PAGE
    add x0, x0, terrain_initialized@PAGEOFF
    ldrb w1, [x0]
    cmp w1, #0
    b.eq .Ldraw_terrain_done // Return if not initialized
    
    // Constants
    mov w21, #8             // char_width = 8
    mov w22, #12            // char_height = 12
    
    // int offset = (frame * SCROLL_SPEED) % TILE_SIZE
    // OPTIMIZATION: bitwise AND since TILE_SIZE=32 is power of 2  
    mov w0, #2              // SCROLL_SPEED = 2
    mul w0, w20, w0         // frame * SCROLL_SPEED
    and w23, w0, #31        // offset = (frame * SCROLL_SPEED) & 31 (equivalent to % 32)
    
    // int tiles_per_screen = (VIS_WIDTH / TILE_SIZE) + 2
    mov w0, #800            // VIS_WIDTH = 800
    mov w1, #32             // TILE_SIZE = 32
    udiv w0, w0, w1         // VIS_WIDTH / TILE_SIZE = 25
    add w24, w0, #2         // tiles_per_screen = 25 + 2 = 27
    
    // int scroll_tiles = (frame * SCROLL_SPEED) / TILE_SIZE
    mov w0, #2              // SCROLL_SPEED = 2
    mul w0, w20, w0         // frame * SCROLL_SPEED
    mov w1, #32             // TILE_SIZE = 32
    udiv w25, w0, w1        // scroll_tiles = (frame * SCROLL_SPEED) / TILE_SIZE
    
    // Get terrain pattern pointer
    adrp x27, terrain_pattern@PAGE
    add x27, x27, terrain_pattern@PAGEOFF
    
    mov w28, #0             // i = 0 (tile index)
    
.Ldraw_tile_loop:
    cmp w28, w24            // i < tiles_per_screen?
    b.ge .Ldraw_terrain_done
    
    // int terrain_idx = (scroll_tiles + i) % TERRAIN_LENGTH
    // OPTIMIZATION: bitwise AND since TERRAIN_LENGTH=64 is power of 2
    add w0, w25, w28        // scroll_tiles + i
    and w0, w0, #63         // terrain_idx = (scroll_tiles + i) & 63 (equivalent to % 64)
    
    // Load terrain tile: terrain_tile_t terrain = terrain_pattern[terrain_idx]
    mov w1, #8              // sizeof(terrain_tile_t) = 8
    mul w2, w0, w1          // terrain_idx * 8
    add x2, x27, w2, uxtw   // &terrain_pattern[terrain_idx]
    ldr w1, [x2]            // terrain.type
    ldr w2, [x2, #4]        // terrain.height
    
    // Store terrain data on stack  
    str w1, [sp, #100]      // terrain.type
    str w2, [sp, #104]      // terrain.height
    
    // int x0 = i * TILE_SIZE - offset
    mov w0, #32             // TILE_SIZE = 32
    mul w0, w28, w0         // i * TILE_SIZE
    sub w0, w0, w23         // x0 = i * TILE_SIZE - offset
    str w0, [sp, #108]      // Store x0
    
    // if (terrain.type == TERRAIN_GAP) continue
    cmp w1, #4              // TERRAIN_GAP = 4
    b.eq .Ldraw_next_tile   // Skip drawing for gaps
    
    // Draw tiles based on height
    mov w0, #0              // row = 0
    str w0, [sp, #112]      // Store row
    
.Ldraw_row_loop:
    ldr w0, [sp, #112]      // Load row
    ldr w1, [sp, #104]      // Load terrain.height
    cmp w0, w1              // row < terrain.height?
    b.ge .Ldraw_next_tile
    
    // int y0 = VIS_HEIGHT - (row + 1) * TILE_SIZE
    add w1, w0, #1          // row + 1
    mov w2, #32             // TILE_SIZE = 32
    mul w1, w1, w2          // (row + 1) * TILE_SIZE
    mov w2, #600            // VIS_HEIGHT = 600
    sub w1, w2, w1          // y0 = VIS_HEIGHT - (row + 1) * TILE_SIZE
    str w1, [sp, #116]      // Store y0
    
    // Choose which ASCII pattern to use
    ldr w1, [sp, #100]      // terrain.type
    ldr w2, [sp, #104]      // terrain.height
    sub w3, w2, #1          // terrain.height - 1
    cmp w0, w3              // row == terrain.height - 1?
    b.ne .Ldraw_use_flat_pattern
    
    // Check if slope pattern should be used
    cmp w1, #2              // TERRAIN_SLOPE_UP = 2
    b.eq .Ldraw_use_slope_up_pattern
    cmp w1, #3              // TERRAIN_SLOPE_DOWN = 3
    b.eq .Ldraw_use_slope_down_pattern
    
.Ldraw_use_flat_pattern:
    adrp x0, tile_flat_pattern@PAGE
    add x0, x0, tile_flat_pattern@PAGEOFF
    b .Ldraw_pattern_chosen
    
.Ldraw_use_slope_up_pattern:
    adrp x0, tile_slope_up_pattern@PAGE
    add x0, x0, tile_slope_up_pattern@PAGEOFF
    b .Ldraw_pattern_chosen
    
.Ldraw_use_slope_down_pattern:
    adrp x0, tile_slope_down_pattern@PAGE
    add x0, x0, tile_slope_down_pattern@PAGEOFF
    
.Ldraw_pattern_chosen:
    str x0, [sp, #124]      // Store pattern pointer
    
    // Draw ASCII characters from the pattern
    // for (int ty = 0; ty < TILE_SIZE; ty += char_height)
    mov w0, #0              // ty = 0
    str w0, [sp, #132]      // Store ty
    
.Ldraw_ty_loop:
    ldr w0, [sp, #132]      // Load ty
    cmp w0, #32             // ty < TILE_SIZE?
    b.ge .Ldraw_next_row
    
    // for (int tx = 0; tx < TILE_SIZE; tx += char_width)
    mov w1, #0              // tx = 0
    str w1, [sp, #136]      // Store tx
    
.Ldraw_tx_loop:
    ldr w1, [sp, #136]      // Load tx
    cmp w1, #32             // tx < TILE_SIZE?
    b.ge .Ldraw_next_ty
    
    // int pattern_x = tx / char_width
    udiv w2, w1, w21        // pattern_x = tx / char_width
    
    // int pattern_y = ty / char_height
    udiv w3, w0, w22        // pattern_y = ty / char_height
    
    // Bounds check: pattern_x < TILE_SIZE/char_width && pattern_y < TILE_SIZE/char_height
    mov w4, #32             // TILE_SIZE = 32
    udiv w5, w4, w21        // TILE_SIZE / char_width = 32 / 8 = 4
    cmp w2, w5
    b.ge .Ldraw_next_tx
    
    udiv w5, w4, w22        // TILE_SIZE / char_height = 32 / 12 = 2 (rounded down)
    cmp w3, w5
    b.ge .Ldraw_next_tx
    
    // int pattern_idx = pattern_y * (TILE_SIZE/char_width) + pattern_x
    mov w4, #32             // TILE_SIZE = 32
    udiv w5, w4, w21        // TILE_SIZE / char_width = 4
    mul w6, w3, w5          // pattern_y * (TILE_SIZE/char_width)
    add w6, w6, w2          // pattern_idx = pattern_y * 4 + pattern_x
    
    // Bounds check: pattern_idx < TILE_SIZE * TILE_SIZE
    mov w4, #1024           // TILE_SIZE * TILE_SIZE = 32 * 32 = 1024
    cmp w6, w4
    b.ge .Ldraw_next_tx
    
    // char c = pattern[pattern_idx]
    ldr x4, [sp, #124]      // Load pattern pointer
    ldrb w5, [x4, w6, uxtw] // Load character c
    
    // if (c != ' ') - Skip transparent characters
    cmp w5, #' '
    b.eq .Ldraw_check_noise
    
    // Calculate screen coordinates
    // int screen_x = x0 + tx
    ldr w6, [sp, #108]      // Load x0
    add w6, w6, w1          // screen_x = x0 + tx
    
    // int screen_y = y0 + ty
    ldr w7, [sp, #116]      // Load y0
    add w7, w7, w0          // screen_y = y0 + ty
    
    // Bounds check: screen_x >= 0 && screen_x < VIS_WIDTH - char_width
    cmp w6, #0
    b.lt .Ldraw_next_tx
    mov w8, #800            // VIS_WIDTH = 800
    sub w8, w8, w21         // VIS_WIDTH - char_width = 800 - 8 = 792
    cmp w6, w8
    b.ge .Ldraw_next_tx
    
    // Bounds check: screen_y >= 0 && screen_y < VIS_HEIGHT - char_height
    cmp w7, #0
    b.lt .Ldraw_next_tx
    mov w8, #600            // VIS_HEIGHT = 600
    sub w8, w8, w22         // VIS_HEIGHT - char_height = 600 - 12 = 588
    cmp w7, w8
    b.ge .Ldraw_next_tx
    
    // Calculate dynamic color for this character
    // uint32_t color = get_dynamic_terrain_color(terrain_type, screen_x, screen_y, frame, audio_level)
    ldr w0, [sp, #100]      // terrain.type
    mov w1, w6              // screen_x
    mov w2, w7              // screen_y
    mov w3, w20             // frame
    ldr s0, [sp, #96]       // audio_level
    str w5, [sp, #140]      // Save character
    str w6, [sp, #144]      // Save screen_x
    str w7, [sp, #148]      // Save screen_y
    bl _get_dynamic_terrain_color_asm
    str w0, [sp, #152]      // Save dynamic color
    
    // Restore values
    ldr w5, [sp, #140]      // Restore character
    ldr w6, [sp, #144]      // Restore screen_x  
    ldr w7, [sp, #148]      // Restore screen_y
    
    // Apply glitch effects to the character
    // char glitched_char = c (default)
    mov w8, w5              // glitched_char = c
    
    // Check for matrix cascade first (overrides other effects)
    // if (should_apply_matrix_cascade(screen_x, screen_y, frame))
    mov w0, w6              // screen_x
    mov w1, w7              // screen_y
    mov w2, w20             // frame
    str w5, [sp, #156]      // Save original character
    str w6, [sp, #160]      // Save screen_x
    str w7, [sp, #164]      // Save screen_y
    str w8, [sp, #168]      // Save glitched_char
    bl _should_apply_matrix_cascade
    
    cmp w0, #0
    b.eq .Ldraw_apply_terrain_glitch
    
    // glitched_char = get_matrix_cascade_char(screen_x, screen_y, frame)
    ldr w0, [sp, #160]      // screen_x
    ldr w1, [sp, #164]      // screen_y
    mov w2, w20             // frame
    bl _get_matrix_cascade_char
    str w0, [sp, #168]      // Update glitched_char
    b .Ldraw_render_char
    
.Ldraw_apply_terrain_glitch:
    // glitched_char = get_glitched_terrain_char(c, screen_x, screen_y, frame)
    ldr w0, [sp, #156]      // original character
    ldr w1, [sp, #160]      // screen_x
    ldr w2, [sp, #164]      // screen_y
    mov w3, w20             // frame
    bl _get_glitched_terrain_char
    str w0, [sp, #168]      // Update glitched_char
    
.Ldraw_render_char:
    // draw_ascii_char(pixels, screen_x, screen_y, glitched_char, dynamic_color, 255)
    mov x0, x19             // pixels
    ldr w1, [sp, #160]      // screen_x
    ldr w2, [sp, #164]      // screen_y
    ldr w3, [sp, #168]      // glitched_char
    ldr w4, [sp, #152]      // dynamic_color (calculated earlier)
    mov w5, #255            // alpha = 255
    bl _draw_ascii_char_asm
    
    b .Ldraw_next_tx
    
.Ldraw_check_noise:
    // Even on transparent areas, occasionally show digital noise
    // Calculate screen coordinates
    ldr w6, [sp, #108]      // Load x0
    add w6, w6, w1          // screen_x = x0 + tx
    
    ldr w7, [sp, #116]      // Load y0
    add w7, w7, w0          // screen_y = y0 + ty
    
    // Bounds check (same as above)
    cmp w6, #0
    b.lt .Ldraw_next_tx
    mov w8, #800            // VIS_WIDTH = 800
    sub w8, w8, w21         // VIS_WIDTH - char_width
    cmp w6, w8
    b.ge .Ldraw_next_tx
    
    cmp w7, #0
    b.lt .Ldraw_next_tx
    mov w8, #600            // VIS_HEIGHT = 600
    sub w8, w8, w22         // VIS_HEIGHT - char_height
    cmp w7, w8
    b.ge .Ldraw_next_tx
    
    // char noise_char = get_digital_noise_char(screen_x, screen_y, frame)
    mov w0, w6              // screen_x
    mov w1, w7              // screen_y
    mov w2, w20             // frame
    str w6, [sp, #172]      // Save screen_x
    str w7, [sp, #176]      // Save screen_y
    bl _get_digital_noise_char
    
    // if (noise_char != ' ')
    cmp w0, #' '
    b.eq .Ldraw_next_tx
    
    // Calculate dynamic color for noise too (using gap terrain type for variety)
    str w0, [sp, #180]      // Save noise_char
    mov w0, #4              // TERRAIN_GAP for noise
    ldr w1, [sp, #172]      // screen_x
    ldr w2, [sp, #176]      // screen_y
    mov w3, w20             // frame
    ldr s0, [sp, #96]       // audio_level
    bl _get_dynamic_terrain_color_asm
    
    // Use dimmer dynamic color for noise: draw_ascii_char(pixels, screen_x, screen_y, noise_char, dynamic_color, 128)
    mov w4, w0              // dynamic_color
    ldr w3, [sp, #180]      // noise_char
    mov x0, x19             // pixels
    ldr w1, [sp, #172]      // screen_x
    ldr w2, [sp, #176]      // screen_y
    mov w5, #128            // alpha = 128 (dimmer)
    bl _draw_ascii_char_asm
    
.Ldraw_next_tx:
    ldr w1, [sp, #136]      // Load tx
    add w1, w1, w21         // tx += char_width
    str w1, [sp, #136]      // Store tx
    b .Ldraw_tx_loop
    
.Ldraw_next_ty:
    ldr w0, [sp, #132]      // Load ty
    add w0, w0, w22         // ty += char_height
    str w0, [sp, #132]      // Store ty
    b .Ldraw_ty_loop
    
.Ldraw_next_row:
    ldr w0, [sp, #112]      // Load row
    add w0, w0, #1          // row++
    str w0, [sp, #112]      // Store row
    b .Ldraw_row_loop
    
.Ldraw_next_tile:
    add w28, w28, #1        // i++
    b .Ldraw_tile_loop
    
.Ldraw_terrain_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #160
    ret

// Compatibility wrapper for old draw_terrain_asm function
// void draw_terrain(uint32_t *pixels, int frame)
// Input: x0 = pixels, w1 = frame
.global _draw_terrain_asm
_draw_terrain_asm:
    // Call enhanced version with default audio level
    adr x2, .Lconst_0_5
    ldr s0, [x2]            // audio_level = 0.5 (moderate)
    b _draw_terrain_enhanced_asm

// Constants
.align 4
.Lconst_magic:
    .long 0x7E44A1          // Magic number for terrain generation

// Floating point constants
.Lconst_0_1:
    .float 0.1
.Lconst_0_15:
    .float 0.15
.Lconst_0_2:
    .float 0.2
.Lconst_0_3:
    .float 0.3
.Lconst_0_5:
    .float 0.5
.Lconst_0_6:
    .float 0.6
.Lconst_0_8:
    .float 0.8
.Lconst_0_9:
    .float 0.9
.Lconst_1_0:
    .float 1.0
.Lconst_100:
    .float 100.0
.Lconst_600:
    .float 600.0
.Lconst_1000:
    .float 1000.0
