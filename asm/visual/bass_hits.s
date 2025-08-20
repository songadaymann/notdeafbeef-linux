
.section __TEXT,__text,regular,pure_instructions
.align 2

// External function declarations
.extern _get_glitched_shape_char
.extern _draw_ascii_char_asm
.extern _cosf
.extern _sinf

// Bass hit data structures
.section __DATA,__data
.align 5

// Bass hit array - 16 hits * 32 bytes each = 512 bytes
// bass_hit_t structure layout:
// - shape_type: 4 bytes (bass_shape_type_t enum)
// - color: 4 bytes (color_t struct: r,g,b,a)
// - alpha: 4 bytes (int)
// - scale: 4 bytes (float)
// - max_size: 4 bytes (float)
// - rotation: 4 bytes (float)
// - rot_speed: 4 bytes (float)
// - active: 4 bytes (bool padded to 4)
// Total: 32 bytes per bass_hit_t
bass_hits_array:
    .space (16 * 32), 0     // MAX_BASS_HITS * sizeof(bass_hit_t)

bass_hits_initialized:
    .space 1, 0             // bool

last_bass_step:
    .space 4, 0             // int

// OPTIMIZATION: Trig lookup tables (256 entries each, 1KB total)
// sin/cos values for angles 0 to 2π with linear interpolation
.align 4
sin_lut:
    .float 0.000000, 0.024541, 0.049068, 0.073565, 0.098017, 0.122411, 0.146730, 0.170962
    .float 0.195090, 0.219101, 0.242980, 0.266713, 0.290285, 0.313682, 0.336890, 0.359895
    .float 0.382683, 0.405241, 0.427555, 0.449611, 0.471397, 0.492898, 0.514103, 0.534998
    .float 0.555570, 0.575808, 0.595699, 0.615232, 0.634393, 0.653173, 0.671559, 0.689541
    .float 0.707107, 0.724247, 0.740951, 0.757209, 0.773010, 0.788346, 0.803208, 0.817585
    .float 0.831470, 0.844854, 0.857729, 0.870087, 0.881921, 0.893224, 0.903989, 0.914210
    .float 0.923880, 0.932993, 0.941544, 0.949528, 0.956940, 0.963776, 0.970031, 0.975702
    .float 0.980785, 0.985278, 0.989177, 0.992480, 0.995185, 0.997290, 0.998795, 0.999699
    .float 1.000000, 0.999699, 0.998795, 0.997290, 0.995185, 0.992480, 0.989177, 0.985278
    .float 0.980785, 0.975702, 0.970031, 0.963776, 0.956940, 0.949528, 0.941544, 0.932993
    .float 0.923880, 0.914210, 0.903989, 0.893224, 0.881921, 0.870087, 0.857729, 0.844854
    .float 0.831470, 0.817585, 0.803208, 0.788346, 0.773010, 0.757209, 0.740951, 0.724247
    .float 0.707107, 0.689541, 0.671559, 0.653173, 0.634393, 0.615232, 0.595699, 0.575808
    .float 0.555570, 0.534998, 0.514103, 0.492898, 0.471397, 0.449611, 0.427555, 0.405241
    .float 0.382683, 0.359895, 0.336890, 0.313682, 0.290285, 0.266713, 0.242980, 0.219101
    .float 0.195090, 0.170962, 0.146730, 0.122411, 0.098017, 0.073565, 0.049068, 0.024541
    .float 0.000000, -0.024541, -0.049068, -0.073565, -0.098017, -0.122411, -0.146730, -0.170962
    .float -0.195090, -0.219101, -0.242980, -0.266713, -0.290285, -0.313682, -0.336890, -0.359895
    .float -0.382683, -0.405241, -0.427555, -0.449611, -0.471397, -0.492898, -0.514103, -0.534998
    .float -0.555570, -0.575808, -0.595699, -0.615232, -0.634393, -0.653173, -0.671559, -0.689541
    .float -0.707107, -0.724247, -0.740951, -0.757209, -0.773010, -0.788346, -0.803208, -0.817585
    .float -0.831470, -0.844854, -0.857729, -0.870087, -0.881921, -0.893224, -0.903989, -0.914210
    .float -0.923880, -0.932993, -0.941544, -0.949528, -0.956940, -0.963776, -0.970031, -0.975702
    .float -0.980785, -0.985278, -0.989177, -0.992480, -0.995185, -0.997290, -0.998795, -0.999699
    .float -1.000000, -0.999699, -0.998795, -0.997290, -0.995185, -0.992480, -0.989177, -0.985278
    .float -0.980785, -0.975702, -0.970031, -0.963776, -0.956940, -0.949528, -0.941544, -0.932993
    .float -0.923880, -0.914210, -0.903989, -0.893224, -0.881921, -0.870087, -0.857729, -0.844854
    .float -0.831470, -0.817585, -0.803208, -0.788346, -0.773010, -0.757209, -0.740951, -0.724247
    .float -0.707107, -0.689541, -0.671559, -0.653173, -0.634393, -0.615232, -0.595699, -0.575808
    .float -0.555570, -0.534998, -0.514103, -0.492898, -0.471397, -0.449611, -0.427555, -0.405241
    .float -0.382683, -0.359895, -0.336890, -0.313682, -0.290285, -0.266713, -0.242980, -0.219101
    .float -0.195090, -0.170962, -0.146730, -0.122411, -0.098017, -0.073565, -0.049068, -0.024541

cos_lut:
    .float 1.000000, 0.999699, 0.998795, 0.997290, 0.995185, 0.992480, 0.989177, 0.985278
    .float 0.980785, 0.975702, 0.970031, 0.963776, 0.956940, 0.949528, 0.941544, 0.932993
    .float 0.923880, 0.914210, 0.903989, 0.893224, 0.881921, 0.870087, 0.857729, 0.844854
    .float 0.831470, 0.817585, 0.803208, 0.788346, 0.773010, 0.757209, 0.740951, 0.724247
    .float 0.707107, 0.689541, 0.671559, 0.653173, 0.634393, 0.615232, 0.595699, 0.575808
    .float 0.555570, 0.534998, 0.514103, 0.492898, 0.471397, 0.449611, 0.427555, 0.405241
    .float 0.382683, 0.359895, 0.336890, 0.313682, 0.290285, 0.266713, 0.242980, 0.219101
    .float 0.195090, 0.170962, 0.146730, 0.122411, 0.098017, 0.073565, 0.049068, 0.024541
    .float 0.000000, -0.024541, -0.049068, -0.073565, -0.098017, -0.122411, -0.146730, -0.170962
    .float -0.195090, -0.219101, -0.242980, -0.266713, -0.290285, -0.313682, -0.336890, -0.359895
    .float -0.382683, -0.405241, -0.427555, -0.449611, -0.471397, -0.492898, -0.514103, -0.534998
    .float -0.555570, -0.575808, -0.595699, -0.615232, -0.634393, -0.653173, -0.671559, -0.689541
    .float -0.707107, -0.724247, -0.740951, -0.757209, -0.773010, -0.788346, -0.803208, -0.817585
    .float -0.831470, -0.844854, -0.857729, -0.870087, -0.881921, -0.893224, -0.903989, -0.914210
    .float -0.923880, -0.932993, -0.941544, -0.949528, -0.956940, -0.963776, -0.970031, -0.975702
    .float -0.980785, -0.985278, -0.989177, -0.992480, -0.995185, -0.997290, -0.998795, -0.999699
    .float -1.000000, -0.999699, -0.998795, -0.997290, -0.995185, -0.992480, -0.989177, -0.985278
    .float -0.980785, -0.975702, -0.970031, -0.963776, -0.956940, -0.949528, -0.941544, -0.932993
    .float -0.923880, -0.914210, -0.903989, -0.893224, -0.881921, -0.870087, -0.857729, -0.844854
    .float -0.831470, -0.817585, -0.803208, -0.788346, -0.773010, -0.757209, -0.740951, -0.724247
    .float -0.707107, -0.689541, -0.671559, -0.653173, -0.634393, -0.615232, -0.595699, -0.575808
    .float -0.555570, -0.534998, -0.514103, -0.492898, -0.471397, -0.449611, -0.427555, -0.405241
    .float -0.382683, -0.359895, -0.336890, -0.313682, -0.290285, -0.266713, -0.242980, -0.219101
    .float -0.195090, -0.170962, -0.146730, -0.122411, -0.098017, -0.073565, -0.049068, -0.024541

.section __TEXT,__text,regular,pure_instructions

// Initialize bass hit system
// void init_bass_hits(void)
.global _init_bass_hits_asm
_init_bass_hits_asm:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Check if already initialized
    adrp x0, bass_hits_initialized@PAGE
    add x0, x0, bass_hits_initialized@PAGEOFF
    ldrb w1, [x0]
    cmp w1, #0
    b.ne .Linit_bass_done   // Return if already initialized
    
    // Get bass hits array pointer
    adrp x1, bass_hits_array@PAGE
    add x1, x1, bass_hits_array@PAGEOFF
    
    // Initialize all bass hits as inactive
    mov w2, #0              // i = 0
.Linit_bass_loop:
    cmp w2, #16             // MAX_BASS_HITS = 16
    b.ge .Linit_bass_set_flag
    
    // Calculate offset: bass_hits[i].active = false
    mov w3, #32             // sizeof(bass_hit_t) = 32
    mul w4, w2, w3          // i * 32
    add w4, w4, #28         // offset to 'active' field (last 4 bytes)
    mov w5, #0              // false = 0
    str w5, [x1, w4, uxtw]  // Store active = false
    
    add w2, w2, #1          // i++
    b .Linit_bass_loop
    
.Linit_bass_set_flag:
    // Set initialized flag
    mov w1, #1
    strb w1, [x0]           // bass_hits_initialized = true
    
.Linit_bass_done:
    ldp x29, x30, [sp], #16
    ret

// Reset bass hit step tracking
// void reset_bass_hit_step_tracking(void)
.global _reset_bass_hit_step_tracking_asm
_reset_bass_hit_step_tracking_asm:
    // last_bass_step = -1
    adrp x0, last_bass_step@PAGE
    add x0, x0, last_bass_step@PAGEOFF
    mov w1, #-1
    str w1, [x0]
    ret

// Helper function to get bass hits array pointer
// bass_hit_t* get_bass_hits_ptr_asm(void)
.global _get_bass_hits_ptr_asm
_get_bass_hits_ptr_asm:
    adrp x0, bass_hits_array@PAGE
    add x0, x0, bass_hits_array@PAGEOFF
    ret

// Helper function to get last bass step pointer
// int* get_last_bass_step_ptr_asm(void)
.global _get_last_bass_step_ptr_asm
_get_last_bass_step_ptr_asm:
    adrp x0, last_bass_step@PAGE
    add x0, x0, last_bass_step@PAGEOFF
    ret

// Helper function to get bass hits initialized flag pointer
// bool* get_bass_hits_initialized_ptr_asm(void)
.global _get_bass_hits_initialized_ptr_asm
_get_bass_hits_initialized_ptr_asm:
    adrp x0, bass_hits_initialized@PAGE
    add x0, x0, bass_hits_initialized@PAGEOFF
    ret

// Create a new bass hit
// static void spawn_bass_hit(float base_hue, uint32_t seed)
// Input: s0 = base_hue (float), w0 = seed (uint32_t)
.global _spawn_bass_hit_asm
_spawn_bass_hit_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str s0, [sp, #64]       // Save base_hue
    str w0, [sp, #68]       // Save seed
    
    // Get bass hits array pointer
    adrp x19, bass_hits_array@PAGE
    add x19, x19, bass_hits_array@PAGEOFF
    
    // Find free slot
    mov w20, #-1            // slot = -1
    mov w21, #0             // i = 0
    
.Lspawn_find_slot:
    cmp w21, #16            // MAX_BASS_HITS = 16
    b.ge .Lspawn_check_slot
    
    // Check if bass_hits[i].active == false
    mov w22, #32            // sizeof(bass_hit_t) = 32
    mul w23, w21, w22       // i * 32
    add w23, w23, #28       // offset to 'active' field
    ldr w24, [x19, w23, uxtw] // Load active flag
    
    cmp w24, #0             // active == false
    b.ne .Lspawn_next_slot
    
    // Found free slot
    mov w20, w21            // slot = i
    b .Lspawn_check_slot
    
.Lspawn_next_slot:
    add w21, w21, #1        // i++
    b .Lspawn_find_slot
    
.Lspawn_check_slot:
    cmp w20, #-1            // if (slot == -1)
    b.eq .Lspawn_done       // return (no free slots)
    
    // Get pointer to bass_hits[slot]
    mov w22, #32            // sizeof(bass_hit_t)
    mul w23, w20, w22       // slot * 32
    add x21, x19, w23, uxtw // hit = &bass_hits[slot]
    
    // srand(seed + slot)
    ldr w0, [sp, #68]       // Load seed
    add w0, w0, w20         // seed + slot
    bl _srand
    
    // Choose random shape type: shape_types[rand() % 5]
    bl _rand
    mov w1, #5
    udiv w2, w0, w1         // w2 = rand() / 5
    msub w22, w2, w1, w0    // w22 = rand() % 5 = shape_type
    
    // Store shape_type: hit->shape_type = shape_type
    str w22, [x21]          // Store at offset 0
    
    // Generate color with hue shift
    // float hue_shift = ((rand() / (float)RAND_MAX) - 0.5f) * 0.4f
    bl _rand
    ucvtf s1, w0            // Convert rand() to float
    
    // Load RAND_MAX constant (2147483647 = 0x7FFFFFFF)
    adr x0, .Lconst_rand_max
    ldr s2, [x0]            // s2 = RAND_MAX as float
    fdiv s1, s1, s2         // s1 = rand() / RAND_MAX
    
    adr x0, .Lconst_0_5
    ldr s2, [x0]            // s2 = 0.5f
    fsub s1, s1, s2         // s1 = (rand() / RAND_MAX) - 0.5f
    
    adr x0, .Lconst_0_4
    ldr s2, [x0]            // s2 = 0.4f
    fmul s1, s1, s2         // s1 = hue_shift = ((rand() / RAND_MAX) - 0.5f) * 0.4f
    
    // hsv_t hit_hsv = {fmod(base_hue + hue_shift, 1.0f), 1.0f, 1.0f}
    ldr s0, [sp, #64]       // Load base_hue
    fadd s0, s0, s1         // base_hue + hue_shift
    
    // fmod(base_hue + hue_shift, 1.0f)
    adr x0, .Lconst_1_0
    ldr s2, [x0]            // s2 = 1.0f
    fdiv s3, s0, s2         // s3 = (base_hue + hue_shift) / 1.0f
    fcvtms w0, s3           // w0 = floor(division)
    scvtf s3, w0            // s3 = floor as float
    fmsub s0, s3, s2, s0    // s0 = fmod result
    
    // Create HSV struct on stack: {h, s, v}
    str s0, [sp, #72]       // h = fmod result
    adr x0, .Lconst_1_0
    ldr s1, [x0]            // s = 1.0f
    str s1, [sp, #76]       // s = 1.0f
    str s1, [sp, #80]       // v = 1.0f (reuse same constant)
    
    // Convert HSV to RGB: hit->color = hsv_to_rgb(hit_hsv)
    add x0, sp, #72         // pointer to HSV struct
    add x1, x21, #4         // pointer to hit->color (offset 4)
    bl _hsv_to_rgb
    
    // Set initial properties
    // hit->alpha = 255
    mov w0, #255
    str w0, [x21, #8]       // Store at offset 8
    
    // hit->scale = 0.1f
    adr x0, .Lconst_0_1
    ldr s0, [x0]
    str s0, [x21, #12]      // Store at offset 12
    
    // hit->max_size = (VIS_WIDTH < VIS_HEIGHT ? VIS_WIDTH : VIS_HEIGHT) * 0.6f
    mov w0, #800            // VIS_WIDTH
    mov w1, #600            // VIS_HEIGHT
    cmp w0, w1
    csel w0, w0, w1, lo     // w0 = min(VIS_WIDTH, VIS_HEIGHT) = 600
    ucvtf s0, w0            // Convert to float
    adr x1, .Lconst_0_6
    ldr s1, [x1]            // s1 = 0.6f
    fmul s0, s0, s1         // s0 = min_dimension * 0.6f
    str s0, [x21, #16]      // Store max_size at offset 16
    
    // hit->rotation = 0.0f
    fmov s0, wzr            // s0 = 0.0f
    str s0, [x21, #20]      // Store at offset 20
    
    // hit->rot_speed = ((rand() / (float)RAND_MAX) - 0.5f) * 0.1f
    bl _rand
    ucvtf s0, w0            // Convert rand() to float
    adr x0, .Lconst_rand_max
    ldr s1, [x0]            // s1 = RAND_MAX
    fdiv s0, s0, s1         // s0 = rand() / RAND_MAX
    adr x0, .Lconst_0_5
    ldr s1, [x0]            // s1 = 0.5f
    fsub s0, s0, s1         // s0 = (rand() / RAND_MAX) - 0.5f
    adr x0, .Lconst_0_1
    ldr s1, [x0]            // s1 = 0.1f
    fmul s0, s0, s1         // s0 = rot_speed
    str s0, [x21, #24]      // Store at offset 24
    
    // hit->active = true
    mov w0, #1
    str w0, [x21, #28]      // Store at offset 28
    
.Lspawn_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// Fast sine lookup using 256-entry table
// Input: s0 = angle (radians), Output: s0 = sin(angle)
.global _sin_lut_asm
_sin_lut_asm:
    // Convert angle to table index: index = (angle / (2*π)) * 256
    adr x1, .Lconst_2pi_inv
    ldr s1, [x1]            // 1/(2π) = 0.159155
    fmul s1, s0, s1         // angle / (2π)
    adr x1, .Lconst_256
    ldr s2, [x1]            // 256.0
    fmul s1, s1, s2         // * 256
    fcvtms w1, s1           // index = floor(angle_norm * 256)
    and w1, w1, #255        // index &= 255 (wrap around)
    
    // Load from sin LUT
    adrp x2, sin_lut@PAGE
    add x2, x2, sin_lut@PAGEOFF
    lsl w1, w1, #2          // index * 4 (float size)
    ldr s0, [x2, w1, uxtw]  // sin_lut[index]
    ret

// Fast cosine lookup using 256-entry table  
// Input: s0 = angle (radians), Output: s0 = cos(angle)
.global _cos_lut_asm
_cos_lut_asm:
    // Convert angle to table index: index = (angle / (2*π)) * 256
    adr x1, .Lconst_2pi_inv
    ldr s1, [x1]            // 1/(2π) = 0.159155
    fmul s1, s0, s1         // angle / (2π)
    adr x1, .Lconst_256
    ldr s2, [x1]            // 256.0
    fmul s1, s1, s2         // * 256
    fcvtms w1, s1           // index = floor(angle_norm * 256)
    and w1, w1, #255        // index &= 255 (wrap around)
    
    // Load from cos LUT
    adrp x2, cos_lut@PAGE
    add x2, x2, cos_lut@PAGEOFF
    lsl w1, w1, #2          // index * 4 (float size)
    ldr s0, [x2, w1, uxtw]  // cos_lut[index]
    ret

// Floating point constants
.align 4
.Lconst_2pi_inv:
    .float 0.159155         // 1/(2π) for angle normalization
.Lconst_256:
    .float 256.0            // LUT size
.Lconst_rand_max:
    .float 2147483647.0     // RAND_MAX as float
.Lconst_0_5:
    .float 0.5
.Lconst_0_4:
    .float 0.4
.Lconst_1_0:
    .float 1.0
.Lconst_0_1:
    .float 0.1
.Lconst_0_6:
    .float 0.6

// Draw ASCII hexagon
// void draw_ascii_hexagon(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame)
// Input: x0=pixels, w1=cx, w2=cy, w3=size, s0=rotation, w4=color, w5=alpha, w6=frame
.global _draw_ascii_hexagon_asm
_draw_ascii_hexagon_asm:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check size threshold
    cmp w3, #8
    b.lt .Lhex_done         // return if size < 8
    
    // Save all parameters to dedicated registers (no more w1-w6 reuse)
    mov x19, x0             // pixels pointer  
    mov w20, w1             // cx
    mov w21, w2             // cy  
    mov w22, w3             // size
    str s0, [sp, #96]       // rotation (on stack)
    mov w23, w4             // color
    mov w24, w5             // alpha
    mov w25, w6             // frame
    
    // Loop counter in dedicated register
    mov w26, #0             // i = 0 (dedicated loop counter)
    
    // for (int i = 0; i < 6; i++)
.Lhex_loop:
    cmp w26, #6
    b.ge .Lhex_done
    
    // float angle = rotation + i * M_PI / 3.0f
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_pi_3    // M_PI / 3.0f ≈ 1.047198
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (M_PI / 3.0f)
    
    // int x = cx + (int)(cosf(angle) * size * 0.7f)  
    // OPTIMIZATION: Use lookup table instead of libm cosf
    bl _cos_lut_asm         // s0 = cos(angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // cos(angle) * size
    adr x0, .Lconst_0_7     
    ldr s1, [x0]            // 0.7f
    fmul s0, s0, s1         // cos(angle) * size * 0.7f
    fcvtns w27, s0          // Convert to int, store in w27
    add w27, w20, w27       // x = cx + result
    
    // int y = cy + (int)(sinf(angle) * size * 0.7f)  
    // Recalculate angle since cosf modified s0
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_pi_3    
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (M_PI / 3.0f)
    
    // OPTIMIZATION: Use lookup table instead of libm sinf
    bl _sin_lut_asm         // s0 = sin(angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // sin(angle) * size
    adr x0, .Lconst_0_7
    ldr s1, [x0]            // 0.7f
    fmul s0, s0, s1         // sin(angle) * size * 0.7f
    fcvtns w28, s0          // Convert to int, store in w28
    add w28, w21, w28       // y = cy + result
    
    // char base_char = hex_chars[i % char_count]
    mov w0, #6              // char_count = 6
    udiv w1, w26, w0        // w1 = i / 6
    msub w0, w1, w0, w26    // w0 = i % 6
    adr x1, .Lhex_chars
    ldrb w0, [x1, w0, uxtw] // Load hex_chars[i % 6]
    
    // char glitched_char = get_glitched_shape_char(base_char, x, y, frame)
    // w0 already has base_char
    mov w1, w27             // x  
    mov w2, w28             // y
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, x, y, glitched_char, color, alpha)
    // w0 already has glitched_char, need to set up all parameters
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w27             // x
    mov w2, w28             // y
    mov w4, w23             // color
    mov w5, w24             // alpha
    bl _draw_ascii_char_asm
    
    // Increment loop counter
    add w26, w26, #1        // i++
    b .Lhex_loop
    
.Lhex_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// Draw ASCII square  
// void draw_ascii_square(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame)
// Input: x0=pixels, w1=cx, w2=cy, w3=size, s0=rotation, w4=color, w5=alpha, w6=frame
.global _draw_ascii_square_asm
_draw_ascii_square_asm:
    stp x29, x30, [sp, #-160]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check size threshold
    cmp w3, #8
    b.lt .Lsquare_done      // return if size < 8
    
    // Save all parameters to dedicated registers
    mov x19, x0             // pixels pointer  
    mov w20, w1             // cx
    mov w21, w2             // cy  
    mov w22, w3             // size (half)
    str s0, [sp, #96]       // rotation (on stack)
    mov w23, w4             // color
    mov w24, w5             // alpha
    mov w25, w6             // frame
    
    // Calculate initial corners (before rotation)
    // corners[4][2] = {{cx-half, cy-half}, {cx+half, cy-half}, {cx+half, cy+half}, {cx-half, cy+half}}
    sub w0, w20, w22        // cx - half
    sub w1, w21, w22        // cy - half
    stp w0, w1, [sp, #104]  // Store corner 0: top-left
    
    add w0, w20, w22        // cx + half  
    sub w1, w21, w22        // cy - half
    stp w0, w1, [sp, #112]  // Store corner 1: top-right
    
    add w0, w20, w22        // cx + half
    add w1, w21, w22        // cy + half  
    stp w0, w1, [sp, #120]  // Store corner 2: bottom-right
    
    sub w0, w20, w22        // cx - half
    add w1, w21, w22        // cy + half
    stp w0, w1, [sp, #128]  // Store corner 3: bottom-left
    
    // Apply rotation to corners and draw them
    mov w26, #0             // i = 0 (corner index)
    
.Lsquare_corner_loop:
    cmp w26, #4
    b.ge .Lsquare_edges     // Done with corners, now draw edges
    
    // Load corner coordinates
    mov w0, #8              // 8 bytes per corner (2 ints)
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to corners array
    add x1, sp, w0, uxtw    // address of corners[i]
    ldp w27, w28, [x1]      // Load corners[i][0], corners[i][1]
    
    // Calculate dx = corners[i][0] - cx, dy = corners[i][1] - cy
    sub w0, w27, w20        // dx = corners[i][0] - cx
    sub w1, w28, w21        // dy = corners[i][1] - cy
    scvtf s0, w0            // dx as float
    scvtf s1, w1            // dy as float
    
    // Rotate: rotated_x = dx * cos(rotation) - dy * sin(rotation)
    //         rotated_y = dx * sin(rotation) + dy * cos(rotation)
    ldr s2, [sp, #96]       // Load rotation
    
    // Calculate cos(rotation)
    fmov s3, s2             // Copy rotation for cos call
    bl _cos_lut_asm         // s0 = cos(rotation) from LUT
    fmov s4, s0             // Save cos result in s4
    
    // Calculate sin(rotation)  
    ldr s2, [sp, #96]       // Reload rotation
    fmov s0, s2             // Set up for sin call
    bl _sin_lut_asm         // s0 = sin(rotation) from LUT
    fmov s5, s0             // Save sin result in s5
    
    // Now compute rotated coordinates
    // rotated_x = dx * cos(rotation) - dy * sin(rotation)
    fmul s6, s0, s4         // dx * cos(rotation)  -- wait, s0 is sin result, need to reload dx
    // Let me reload dx, dy
    sub w0, w27, w20        // dx = corners[i][0] - cx
    sub w1, w28, w21        // dy = corners[i][1] - cy  
    scvtf s0, w0            // dx as float
    scvtf s1, w1            // dy as float
    
    fmul s6, s0, s4         // dx * cos(rotation)
    fmul s7, s1, s5         // dy * sin(rotation)
    fsub s6, s6, s7         // rotated_x = dx * cos - dy * sin
    
    // rotated_y = dx * sin(rotation) + dy * cos(rotation)
    fmul s7, s0, s5         // dx * sin(rotation)
    fmul s8, s1, s4         // dy * cos(rotation)
    fadd s7, s7, s8         // rotated_y = dx * sin + dy * cos
    
    // Convert back to integers and add center
    fcvtns w0, s6           // rotated_x as int
    fcvtns w1, s7           // rotated_y as int
    add w27, w20, w0        // final_x = cx + rotated_x
    add w28, w21, w1        // final_y = cy + rotated_y
    
    // Store rotated corner back
    mov w0, #8              // 8 bytes per corner
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to corners array
    add x1, sp, w0, uxtw    // address of corners[i]
    stp w27, w28, [x1]      // Store rotated coordinates
    
    // Get character: base_char = square_chars[i % char_count]
    mov w0, #6              // char_count = 6
    udiv w1, w26, w0        // w1 = i / 6
    msub w0, w1, w0, w26    // w0 = i % 6
    adr x1, .Lsquare_chars
    ldrb w0, [x1, w0, uxtw] // Load square_chars[i % 6]
    
    // char glitched_char = get_glitched_shape_char(base_char, x, y, frame)
    // w0 already has base_char
    mov w1, w27             // x  
    mov w2, w28             // y
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, x, y, glitched_char, color, alpha)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w27             // x
    mov w2, w28             // y
    mov w4, w23             // color
    mov w5, w24             // alpha
    bl _draw_ascii_char_asm
    
    // Increment corner index
    add w26, w26, #1        // i++
    b .Lsquare_corner_loop
    
.Lsquare_edges:
    // Draw square edges connecting corners
    mov w26, #0             // i = 0 (edge index)
    
.Lsquare_edge_loop:
    cmp w26, #4
    b.ge .Lsquare_done      // Done with all edges
    
    // Calculate next corner index: next = (i + 1) % 4
    add w0, w26, #1         // i + 1
    mov w1, #4              // 4 corners
    udiv w2, w0, w1         // (i + 1) / 4
    msub w27, w2, w1, w0    // next = (i + 1) % 4
    
    // Load current corner coordinates
    mov w0, #8              // 8 bytes per corner
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to corners array
    add x1, sp, w0, uxtw    // address of corners[i]
    ldp w1, w2, [x1]        // Load corners[i][0], corners[i][1]
    
    // Load next corner coordinates  
    mov w0, #8              // 8 bytes per corner
    mul w0, w27, w0         // next * 8
    add w0, w0, #104        // offset to corners array
    add x3, sp, w0, uxtw    // address of corners[next]
    ldp w3, w4, [x3]        // Load corners[next][0], corners[next][1]
    
    // Calculate steps = (abs(next_x - curr_x) + abs(next_y - curr_y)) / 12
    sub w5, w3, w1          // next_x - curr_x
    cmp w5, #0
    cneg w5, w5, mi         // abs(next_x - curr_x)
    
    sub w6, w4, w2          // next_y - curr_y  
    cmp w6, #0
    cneg w6, w6, mi         // abs(next_y - curr_y)
    
    add w5, w5, w6          // sum of distances
    mov w6, #12
    udiv w28, w5, w6        // steps = distance / 12
    
    // Save corner coordinates for edge drawing
    str w1, [sp, #136]      // curr_x
    str w2, [sp, #140]      // curr_y (4-byte aligned)  
    str w3, [sp, #144]      // next_x
    str w4, [sp, #148]      // next_y
    
    // Draw line between corners
    mov w27, #1             // step = 1 (start from 1, not 0)
    
.Lsquare_line_loop:
    cmp w27, w28            // step < steps?
    b.ge .Lsquare_next_edge
    
    // Calculate t = (float)step / steps
    scvtf s0, w27           // step as float
    scvtf s1, w28           // steps as float
    fdiv s2, s0, s1         // t = step / steps
    
    // Calculate line coordinates
    // line_x = curr_x + (int)(t * (next_x - curr_x))
    ldr w0, [sp, #136]      // curr_x
    ldr w1, [sp, #144]      // next_x
    sub w1, w1, w0          // next_x - curr_x
    scvtf s0, w1            // (next_x - curr_x) as float
    fmul s0, s2, s0         // t * (next_x - curr_x)
    fcvtns w1, s0           // convert to int
    add w1, w0, w1          // line_x = curr_x + result
    
    // line_y = curr_y + (int)(t * (next_y - curr_y))
    ldr w0, [sp, #140]      // curr_y
    ldr w2, [sp, #148]      // next_y
    sub w2, w2, w0          // next_y - curr_y
    scvtf s0, w2            // (next_y - curr_y) as float
    fmul s0, s2, s0         // t * (next_y - curr_y)
    fcvtns w2, s0           // convert to int
    add w2, w0, w2          // line_y = curr_y + result
    
    // char line_char = get_glitched_shape_char('-', line_x, line_y, frame)
    mov w0, #'-'            // base character for lines
    // w1 already has line_x
    // w2 already has line_y  
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, line_x, line_y, glitched_char, color, alpha - 50)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    // w1 already has line_x
    // w2 already has line_y
    mov w4, w23             // color
    sub w5, w24, #50        // alpha - 50
    cmp w5, #0              // Ensure alpha doesn't go negative
    csel w5, w5, wzr, ge    // max(alpha - 50, 0)
    bl _draw_ascii_char_asm
    
    // Increment step
    add w27, w27, #1        // step++
    b .Lsquare_line_loop
    
.Lsquare_next_edge:
    // Increment edge index
    add w26, w26, #1        // i++
    b .Lsquare_edge_loop
    
.Lsquare_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #160
    ret

// Draw ASCII triangle
// void draw_ascii_triangle(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame)
// Input: x0=pixels, w1=cx, w2=cy, w3=size, s0=rotation, w4=color, w5=alpha, w6=frame
.global _draw_ascii_triangle_asm
_draw_ascii_triangle_asm:
    stp x29, x30, [sp, #-144]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check size threshold
    cmp w3, #8
    b.lt .Ltriangle_done    // return if size < 8
    
    // Save all parameters to dedicated registers
    mov x19, x0             // pixels pointer  
    mov w20, w1             // cx
    mov w21, w2             // cy  
    mov w22, w3             // size
    str s0, [sp, #96]       // rotation (on stack)
    mov w23, w4             // color
    mov w24, w5             // alpha
    mov w25, w6             // frame
    
    // Loop counter in dedicated register
    mov w26, #0             // i = 0 (vertex index, 0-2)
    
    // for (int i = 0; i < 3; i++)
.Ltriangle_vertex_loop:
    cmp w26, #3
    b.ge .Ltriangle_done
    
    // float angle = rotation + i * 2.0f * M_PI / 3.0f
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_2pi_3   // 2.0f * M_PI / 3.0f ≈ 2.094395
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (2.0f * M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (2.0f * M_PI / 3.0f)
    
    // int x = cx + (int)(cosf(angle) * size * 0.8f)
    bl _cos_lut_asm         // s0 = cos(angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // cos(angle) * size
    adr x0, .Lconst_0_8     
    ldr s1, [x0]            // 0.8f
    fmul s0, s0, s1         // cos(angle) * size * 0.8f
    fcvtns w27, s0          // Convert to int, store in w27
    add w27, w20, w27       // x = cx + result
    
    // int y = cy + (int)(sinf(angle) * size * 0.8f)  
    // Recalculate angle since cosf modified s0
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_2pi_3    
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (2.0f * M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (2.0f * M_PI / 3.0f)
    
    bl _sin_lut_asm         // s0 = sin(angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // sin(angle) * size
    adr x0, .Lconst_0_8
    ldr s1, [x0]            // 0.8f
    fmul s0, s0, s1         // sin(angle) * size * 0.8f
    fcvtns w28, s0          // Convert to int, store in w28
    add w28, w21, w28       // y = cy + result
    
    // Store current vertex coordinates for line drawing
    str w27, [sp, #100]     // Store current x
    str w28, [sp, #104]     // Store current y
    
    // char base_char = triangle_chars[i % char_count]
    mov w0, #5              // char_count = 5
    udiv w1, w26, w0        // w1 = i / 5
    msub w0, w1, w0, w26    // w0 = i % 5
    adr x1, .Ltriangle_chars
    ldrb w0, [x1, w0, uxtw] // Load triangle_chars[i % 5]
    
    // char glitched_char = get_glitched_shape_char(base_char, x, y, frame)
    // w0 already has base_char
    mov w1, w27             // x  
    mov w2, w28             // y
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, x, y, glitched_char, color, alpha)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w27             // x
    mov w2, w28             // y
    mov w4, w23             // color
    mov w5, w24             // alpha
    bl _draw_ascii_char_asm
    
    // Calculate next vertex for line drawing
    // float next_angle = rotation + ((i + 1) % 3) * 2.0f * M_PI / 3.0f
    add w0, w26, #1         // i + 1
    mov w1, #3              // 3 vertices
    udiv w2, w0, w1         // (i + 1) / 3
    msub w0, w2, w1, w0     // next_i = (i + 1) % 3
    
    scvtf s1, w0            // Convert next_i to float
    adr x1, .Lconst_2pi_3   
    ldr s2, [x1]
    fmul s1, s1, s2         // next_i * (2.0f * M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // next_angle = rotation + next_i * (2.0f * M_PI / 3.0f)
    
    // int next_x = cx + (int)(cosf(next_angle) * size * 0.8f)
    bl _cos_lut_asm         // s0 = cos(next_angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // cos(next_angle) * size
    adr x1, .Lconst_0_8     
    ldr s1, [x1]            // 0.8f
    fmul s0, s0, s1         // cos(next_angle) * size * 0.8f
    fcvtns w0, s0           // Convert to int
    add w0, w20, w0         // next_x = cx + result
    str w0, [sp, #108]      // Store next_x
    
    // int next_y = cy + (int)(sinf(next_angle) * size * 0.8f)
    // Recalculate next_angle since cosf modified s0
    add w0, w26, #1         // i + 1
    mov w1, #3              // 3 vertices
    udiv w2, w0, w1         // (i + 1) / 3
    msub w0, w2, w1, w0     // next_i = (i + 1) % 3
    
    scvtf s1, w0            // Convert next_i to float
    adr x1, .Lconst_2pi_3   
    ldr s2, [x1]
    fmul s1, s1, s2         // next_i * (2.0f * M_PI / 3.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // next_angle
    
    bl _sin_lut_asm         // s0 = sin(next_angle) from LUT
    scvtf s1, w22           // Convert size to float
    fmul s0, s0, s1         // sin(next_angle) * size
    adr x1, .Lconst_0_8
    ldr s1, [x1]            // 0.8f
    fmul s0, s0, s1         // sin(next_angle) * size * 0.8f
    fcvtns w0, s0           // Convert to int
    add w0, w21, w0         // next_y = cy + result
    
    // Store next_y properly first
    str w0, [sp, #112]      // Store next_y
    
    // Draw line between current vertex and next vertex
    // Load coordinates into dedicated registers
    ldr w1, [sp, #100]      // curr_x
    ldr w2, [sp, #104]      // curr_y
    ldr w3, [sp, #108]      // next_x
    ldr w4, [sp, #112]      // next_y
    
    // Store these in a way that won't get corrupted
    str w1, [sp, #116]      // Store curr_x
    str w2, [sp, #120]      // Store curr_y  
    str w3, [sp, #124]      // Store next_x
    str w4, [sp, #128]      // Store next_y
    
    // Calculate steps = abs(next_x - curr_x) + abs(next_y - curr_y)
    sub w5, w3, w1          // next_x - curr_x
    cmp w5, #0
    cneg w5, w5, mi         // abs(next_x - curr_x)
    
    sub w6, w4, w2          // next_y - curr_y  
    cmp w6, #0
    cneg w6, w6, mi         // abs(next_y - curr_y)
    
    add w5, w5, w6          // sum of distances
    mov w6, #12
    udiv w0, w5, w6         // steps = distance / 12
    
    // Draw line points
    mov w27, #1             // step = 1 (start from 1, not 0)
    
.Ltriangle_line_loop:
    cmp w27, w0             // step < steps?
    b.ge .Ltriangle_next_vertex
    
    // Calculate t = (float)step / steps
    scvtf s0, w27           // step as float
    scvtf s1, w0            // steps as float
    fdiv s2, s0, s1         // t = step / steps
    
    // Calculate line coordinates using stored values
    // line_x = curr_x + (int)(t * (next_x - curr_x))
    ldr w1, [sp, #116]      // Reload curr_x
    ldr w3, [sp, #124]      // Reload next_x
    sub w5, w3, w1          // next_x - curr_x
    scvtf s0, w5            // (next_x - curr_x) as float
    fmul s0, s2, s0         // t * (next_x - curr_x)
    fcvtns w5, s0           // convert to int
    add w5, w1, w5          // line_x = curr_x + result
    
    // line_y = curr_y + (int)(t * (next_y - curr_y))
    ldr w2, [sp, #120]      // Reload curr_y
    ldr w4, [sp, #128]      // Reload next_y
    sub w6, w4, w2          // next_y - curr_y
    scvtf s0, w6            // (next_y - curr_y) as float
    fmul s0, s2, s0         // t * (next_y - curr_y)
    fcvtns w6, s0           // convert to int
    add w6, w2, w6          // line_y = curr_y + result
    
    // char line_char = get_glitched_shape_char('-', line_x, line_y, frame)
    mov w0, #'-'            // base character for lines
    mov w1, w5              // line_x
    mov w2, w6              // line_y  
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, line_x, line_y, glitched_char, color, alpha - 50)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w5              // line_x
    mov w2, w6              // line_y
    mov w4, w23             // color
    sub w5, w24, #50        // alpha - 50
    cmp w5, #0              // Ensure alpha doesn't go negative
    csel w5, w5, wzr, ge    // max(alpha - 50, 0)
    bl _draw_ascii_char_asm
    
    // Increment step
    add w27, w27, #1        // step++
    b .Ltriangle_line_loop
    
.Ltriangle_next_vertex:
    // Increment vertex index
    add w26, w26, #1        // i++
    b .Ltriangle_vertex_loop

.Ltriangle_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #144
    ret

// Draw ASCII diamond
// void draw_ascii_diamond(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame)
// Input: x0=pixels, w1=cx, w2=cy, w3=size, s0=rotation, w4=color, w5=alpha, w6=frame
.global _draw_ascii_diamond_asm
_draw_ascii_diamond_asm:
    stp x29, x30, [sp, #-144]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check size threshold
    cmp w3, #8
    b.lt .Ldiamond_done     // return if size < 8
    
    // Save all parameters to dedicated registers
    mov x19, x0             // pixels pointer  
    mov w20, w1             // cx
    mov w21, w2             // cy  
    mov w22, w3             // size
    str s0, [sp, #96]       // rotation (on stack)
    mov w23, w4             // color
    mov w24, w5             // alpha
    mov w25, w6             // frame
    
    // Calculate diamond points (4 points: top, right, bottom, left)
    // points[4][2] = {{cx, cy-size}, {cx+size, cy}, {cx, cy+size}, {cx-size, cy}}
    mov w0, w20             // cx
    sub w1, w21, w22        // cy - size
    stp w0, w1, [sp, #104]  // Store point 0: top
    
    add w0, w20, w22        // cx + size  
    mov w1, w21             // cy
    stp w0, w1, [sp, #112]  // Store point 1: right
    
    mov w0, w20             // cx
    add w1, w21, w22        // cy + size  
    stp w0, w1, [sp, #120]  // Store point 2: bottom
    
    sub w0, w20, w22        // cx - size
    mov w1, w21             // cy
    stp w0, w1, [sp, #128]  // Store point 3: left
    
    // Apply rotation to points and draw them
    mov w26, #0             // i = 0 (point index)
    
.Ldiamond_point_loop:
    cmp w26, #4
    b.ge .Ldiamond_edges    // Done with points, now draw edges
    
    // Load point coordinates
    mov w0, #8              // 8 bytes per point (2 ints)
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to points array
    add x1, sp, w0, uxtw    // address of points[i]
    ldp w27, w28, [x1]      // Load points[i][0], points[i][1]
    
    // Calculate dx = points[i][0] - cx, dy = points[i][1] - cy
    sub w0, w27, w20        // dx = points[i][0] - cx
    sub w1, w28, w21        // dy = points[i][1] - cy
    scvtf s0, w0            // dx as float
    scvtf s1, w1            // dy as float
    
    // Rotate: rotated_x = dx * cos(rotation) - dy * sin(rotation)
    //         rotated_y = dx * sin(rotation) + dy * cos(rotation)
    ldr s2, [sp, #96]       // Load rotation
    
    // Calculate cos(rotation)
    fmov s3, s2             // Copy rotation for cos call
    bl _cos_lut_asm         // s0 = cos(rotation) from LUT
    fmov s4, s0             // Save cos result in s4
    
    // Calculate sin(rotation)  
    ldr s2, [sp, #96]       // Reload rotation
    fmov s0, s2             // Set up for sin call
    bl _sin_lut_asm         // s0 = sin(rotation) from LUT
    fmov s5, s0             // Save sin result in s5
    
    // Reload dx, dy
    sub w0, w27, w20        // dx = points[i][0] - cx
    sub w1, w28, w21        // dy = points[i][1] - cy  
    scvtf s0, w0            // dx as float
    scvtf s1, w1            // dy as float
    
    // Now compute rotated coordinates
    fmul s6, s0, s4         // dx * cos(rotation)
    fmul s7, s1, s5         // dy * sin(rotation)
    fsub s6, s6, s7         // rotated_x = dx * cos - dy * sin
    
    fmul s7, s0, s5         // dx * sin(rotation)
    fmul s8, s1, s4         // dy * cos(rotation)
    fadd s7, s7, s8         // rotated_y = dx * sin + dy * cos
    
    // Convert back to integers and add center
    fcvtns w0, s6           // rotated_x as int
    fcvtns w1, s7           // rotated_y as int
    add w27, w20, w0        // final_x = cx + rotated_x
    add w28, w21, w1        // final_y = cy + rotated_y
    
    // Store rotated point back
    mov w0, #8              // 8 bytes per point
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to points array
    add x1, sp, w0, uxtw    // address of points[i]
    stp w27, w28, [x1]      // Store rotated coordinates
    
    // Get character: base_char = diamond_chars[i % char_count]
    mov w0, #5              // char_count = 5
    udiv w1, w26, w0        // w1 = i / 5
    msub w0, w1, w0, w26    // w0 = i % 5
    adr x1, .Ldiamond_chars
    ldrb w0, [x1, w0, uxtw] // Load diamond_chars[i % 5]
    
    // char glitched_char = get_glitched_shape_char(base_char, x, y, frame)
    // w0 already has base_char
    mov w1, w27             // x  
    mov w2, w28             // y
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, x, y, glitched_char, color, alpha)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w27             // x
    mov w2, w28             // y
    mov w4, w23             // color
    mov w5, w24             // alpha
    bl _draw_ascii_char_asm
    
    // Increment point index
    add w26, w26, #1        // i++
    b .Ldiamond_point_loop
    
.Ldiamond_edges:
    // Draw diamond edges connecting points
    mov w26, #0             // i = 0 (edge index)
    
.Ldiamond_edge_loop:
    cmp w26, #4
    b.ge .Ldiamond_done     // Done with all edges
    
    // Calculate next point index: next = (i + 1) % 4
    add w0, w26, #1         // i + 1
    mov w1, #4              // 4 points
    udiv w2, w0, w1         // (i + 1) / 4
    msub w27, w2, w1, w0    // next = (i + 1) % 4
    
    // Load current point coordinates
    mov w0, #8              // 8 bytes per point
    mul w0, w26, w0         // i * 8
    add w0, w0, #104        // offset to points array
    add x1, sp, w0, uxtw    // address of points[i]
    ldp w1, w2, [x1]        // Load points[i][0], points[i][1]
    
    // Load next point coordinates  
    mov w0, #8              // 8 bytes per point
    mul w0, w27, w0         // next * 8
    add w0, w0, #104        // offset to points array
    add x3, sp, w0, uxtw    // address of points[next]
    ldp w3, w4, [x3]        // Load points[next][0], points[next][1]
    
    // Calculate steps = (abs(next_x - curr_x) + abs(next_y - curr_y)) / 12
    sub w5, w3, w1          // next_x - curr_x
    cmp w5, #0
    cneg w5, w5, mi         // abs(next_x - curr_x)
    
    sub w6, w4, w2          // next_y - curr_y  
    cmp w6, #0
    cneg w6, w6, mi         // abs(next_y - curr_y)
    
    add w5, w5, w6          // sum of distances
    mov w6, #12
    udiv w28, w5, w6        // steps = distance / 12
    
    // Save point coordinates for edge drawing
    str w1, [sp, #136]      // curr_x
    str w2, [sp, #140]      // curr_y
    str w3, [sp, #144]      // next_x (note: using unused stack space)
    str w4, [sp, #148]      // next_y
    
    // Draw line between points
    mov w27, #1             // step = 1 (start from 1, not 0)
    
.Ldiamond_line_loop:
    cmp w27, w28            // step < steps?
    b.ge .Ldiamond_next_edge
    
    // Calculate t = (float)step / steps
    scvtf s0, w27           // step as float
    scvtf s1, w28           // steps as float
    fdiv s2, s0, s1         // t = step / steps
    
    // Calculate line coordinates
    // line_x = curr_x + (int)(t * (next_x - curr_x))
    ldr w0, [sp, #136]      // curr_x
    ldr w1, [sp, #144]      // next_x
    sub w1, w1, w0          // next_x - curr_x
    scvtf s0, w1            // (next_x - curr_x) as float
    fmul s0, s2, s0         // t * (next_x - curr_x)
    fcvtns w1, s0           // convert to int
    add w1, w0, w1          // line_x = curr_x + result
    
    // line_y = curr_y + (int)(t * (next_y - curr_y))
    ldr w0, [sp, #140]      // curr_y
    ldr w2, [sp, #148]      // next_y
    sub w2, w2, w0          // next_y - curr_y
    scvtf s0, w2            // (next_y - curr_y) as float
    fmul s0, s2, s0         // t * (next_y - curr_y)
    fcvtns w2, s0           // convert to int
    add w2, w0, w2          // line_y = curr_y + result
    
    // char line_char = get_glitched_shape_char('=', line_x, line_y, frame)
    mov w0, #'='            // base character for diamond lines
    // w1 already has line_x
    // w2 already has line_y  
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, line_x, line_y, glitched_char, color, alpha - 50)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    // w1 already has line_x
    // w2 already has line_y
    mov w4, w23             // color
    sub w5, w24, #50        // alpha - 50
    cmp w5, #0              // Ensure alpha doesn't go negative
    csel w5, w5, wzr, ge    // max(alpha - 50, 0)
    bl _draw_ascii_char_asm
    
    // Increment step
    add w27, w27, #1        // step++
    b .Ldiamond_line_loop
    
.Ldiamond_next_edge:
    // Increment edge index
    add w26, w26, #1        // i++
    b .Ldiamond_edge_loop
    
.Ldiamond_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #144
    ret

// Draw ASCII star
// void draw_ascii_star(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame)
// Input: x0=pixels, w1=cx, w2=cy, w3=size, s0=rotation, w4=color, w5=alpha, w6=frame
.global _draw_ascii_star_asm
_draw_ascii_star_asm:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check size threshold
    cmp w3, #8
    b.lt .Lstar_done        // return if size < 8
    
    // Save all parameters to dedicated registers
    mov x19, x0             // pixels pointer  
    mov w20, w1             // cx
    mov w21, w2             // cy  
    mov w22, w3             // size
    str s0, [sp, #96]       // rotation (on stack)
    mov w23, w4             // color
    mov w24, w5             // alpha
    mov w25, w6             // frame
    
    // Loop counter in dedicated register
    mov w26, #0             // i = 0 (point index, 0-9 for 10 points)
    
    // for (int i = 0; i < 10; i++) - 5-pointed star with inner/outer points
.Lstar_point_loop:
    cmp w26, #10
    b.ge .Lstar_done
    
    // float angle = rotation + i * M_PI / 5.0f
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_pi_5    // M_PI / 5.0f ≈ 0.628318
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (M_PI / 5.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (M_PI / 5.0f)
    
    // float radius = (i % 2 == 0) ? size * 0.8f : size * 0.4f; // Alternate between outer and inner
    mov w0, #2
    udiv w1, w26, w0        // w1 = i / 2
    msub w0, w1, w0, w26    // w0 = i % 2
    
    scvtf s1, w22           // Convert size to float
    cmp w0, #0              // i % 2 == 0?
    b.ne .Lstar_inner_radius
    
    // Outer radius: size * 0.8f
    adr x0, .Lconst_0_8     
    ldr s2, [x0]            // 0.8f
    fmul s1, s1, s2         // size * 0.8f
    b .Lstar_calc_pos
    
.Lstar_inner_radius:
    // Inner radius: size * 0.4f
    adr x0, .Lconst_0_4     
    ldr s2, [x0]            // 0.4f
    fmul s1, s1, s2         // size * 0.4f
    
.Lstar_calc_pos:
    // s1 now contains the radius
    // int x = cx + (int)(cosf(angle) * radius)
    bl _cos_lut_asm         // s0 = cos(angle) from LUT
    fmul s0, s0, s1         // cos(angle) * radius
    fcvtns w27, s0          // Convert to int, store in w27
    add w27, w20, w27       // x = cx + result
    
    // int y = cy + (int)(sinf(angle) * radius)  
    // Recalculate angle since cosf modified s0
    scvtf s1, w26           // Convert i to float
    adr x0, .Lconst_pi_5    
    ldr s2, [x0]
    fmul s1, s1, s2         // i * (M_PI / 5.0f)
    ldr s0, [sp, #96]       // Load rotation
    fadd s0, s0, s1         // angle = rotation + i * (M_PI / 5.0f)
    
    // Recalculate radius
    mov w0, #2
    udiv w1, w26, w0        // w1 = i / 2
    msub w0, w1, w0, w26    // w0 = i % 2
    
    scvtf s1, w22           // Convert size to float
    cmp w0, #0              // i % 2 == 0?
    b.ne .Lstar_inner_radius2
    
    // Outer radius: size * 0.8f
    adr x0, .Lconst_0_8     
    ldr s2, [x0]            // 0.8f
    fmul s1, s1, s2         // size * 0.8f
    b .Lstar_calc_y
    
.Lstar_inner_radius2:
    // Inner radius: size * 0.4f
    adr x0, .Lconst_0_4     
    ldr s2, [x0]            // 0.4f
    fmul s1, s1, s2         // size * 0.4f
    
.Lstar_calc_y:
    bl _sin_lut_asm         // s0 = sin(angle) from LUT
    fmul s0, s0, s1         // sin(angle) * radius
    fcvtns w28, s0          // Convert to int, store in w28
    add w28, w21, w28       // y = cy + result
    
    // char base_char = star_chars[i % char_count]
    mov w0, #8              // char_count = 8
    udiv w1, w26, w0        // w1 = i / 8
    msub w0, w1, w0, w26    // w0 = i % 8
    adr x1, .Lstar_chars
    ldrb w0, [x1, w0, uxtw] // Load star_chars[i % 8]
    
    // char glitched_char = get_glitched_shape_char(base_char, x, y, frame)
    // w0 already has base_char
    mov w1, w27             // x  
    mov w2, w28             // y
    mov w3, w25             // frame
    bl _get_glitched_shape_char
    // Result in w0 = glitched_char
    
    // draw_ascii_char(pixels, x, y, glitched_char, color, alpha)
    mov w3, w0              // glitched_char
    mov x0, x19             // pixels
    mov w1, w27             // x
    mov w2, w28             // y
    mov w4, w23             // color
    mov w5, w24             // alpha
    bl _draw_ascii_char_asm
    
    // Increment loop counter
    add w26, w26, #1        // i++
    b .Lstar_point_loop
    
.Lstar_done:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// Update all active bass hits
// void update_bass_hits(float elapsed_ms, float step_sec, float base_hue, uint32_t seed)
// Input: s0=elapsed_ms, s1=step_sec, s2=base_hue, w0=seed
.global _update_bass_hits_asm
_update_bass_hits_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str s0, [sp, #48]       // elapsed_ms
    str s1, [sp, #52]       // step_sec
    str s2, [sp, #56]       // base_hue
    str w0, [sp, #60]       // seed
    
    // Check if initialized
    adrp x0, bass_hits_initialized@PAGE
    add x0, x0, bass_hits_initialized@PAGEOFF
    ldrb w1, [x0]
    cmp w1, #0
    b.eq .Lupdate_done      // Return if not initialized
    
    // Calculate current step: (int)(elapsed_ms / 1000.0f / step_sec) % 32
    ldr s0, [sp, #48]       // elapsed_ms
    adr x0, .Lconst_1000
    ldr s1, [x0]            // 1000.0f
    fdiv s0, s0, s1         // elapsed_ms / 1000.0f
    ldr s1, [sp, #52]       // step_sec
    fdiv s0, s0, s1         // elapsed_ms / 1000.0f / step_sec
    fcvtzs w19, s0          // Convert to int
    mov w0, #32
    udiv w1, w19, w0        // current_step / 32
    msub w19, w1, w0, w19   // current_step = current_step % 32
    
    // Check if we should spawn: current_step % (STEPS_PER_BEAT * 8) == 0
    mov w0, #32             // STEPS_PER_BEAT * 8 = 4 * 8 = 32
    udiv w1, w19, w0        // current_step / 32
    msub w0, w1, w0, w19    // current_step % 32
    cmp w0, #0
    b.ne .Lupdate_check_hits // Skip spawn if not on beat
    
    // Check if different from last step
    adrp x0, last_bass_step@PAGE
    add x0, x0, last_bass_step@PAGEOFF
    ldr w1, [x0]
    cmp w19, w1
    b.eq .Lupdate_check_hits // Skip if same step
    
    // Update last step and spawn
    str w19, [x0]           // last_bass_step = current_step
    
    // Call spawn_bass_hit(base_hue, seed + current_step)
    ldr s0, [sp, #56]       // base_hue
    ldr w1, [sp, #60]       // seed
    add w0, w1, w19         // seed + current_step
    bl _spawn_bass_hit_asm
    
.Lupdate_check_hits:
    // Update all active bass hits
    adrp x19, bass_hits_array@PAGE
    add x19, x19, bass_hits_array@PAGEOFF
    mov w20, #0             // i = 0
    
.Lupdate_hit_loop:
    cmp w20, #16            // MAX_BASS_HITS = 16
    b.ge .Lupdate_done
    
    // Get pointer to bass_hits[i]
    mov w0, #32             // sizeof(bass_hit_t) = 32
    mul w1, w20, w0         // i * 32
    add x21, x19, w1, uxtw  // hit = &bass_hits[i]
    
    // Check if active: if (!hit->active) continue
    ldr w0, [x21, #28]      // Load active flag (offset 28)
    cmp w0, #0
    b.eq .Lupdate_next_hit  // Skip if not active
    
    // Update scale: if (hit->scale < 1.0f) hit->scale += 0.15f
    ldr s0, [x21, #12]      // Load scale (offset 12)
    adr x0, .Lconst_1_0
    ldr s1, [x0]            // 1.0f
    fcmp s0, s1
    b.ge .Lupdate_scale_done
    
    adr x0, .Lconst_0_15
    ldr s1, [x0]            // 0.15f
    fadd s0, s0, s1         // scale += 0.15f
    str s0, [x21, #12]      // Store updated scale
    
.Lupdate_scale_done:
    // Update alpha: hit->alpha = hit->alpha > 8 ? hit->alpha - 8 : 0
    ldr w0, [x21, #8]       // Load alpha (offset 8)
    cmp w0, #8
    b.le .Lupdate_alpha_zero
    
    sub w0, w0, #8          // alpha - 8
    b .Lupdate_alpha_store
    
.Lupdate_alpha_zero:
    mov w0, #0              // alpha = 0
    
.Lupdate_alpha_store:
    str w0, [x21, #8]       // Store updated alpha
    
    // Update rotation: hit->rotation += hit->rot_speed
    ldr s0, [x21, #20]      // Load rotation (offset 20)
    ldr s1, [x21, #24]      // Load rot_speed (offset 24)
    fadd s0, s0, s1         // rotation += rot_speed
    str s0, [x21, #20]      // Store updated rotation
    
    // Check if should deactivate: if (hit->alpha <= 0) hit->active = false
    ldr w0, [x21, #8]       // Load alpha
    cmp w0, #0
    b.gt .Lupdate_next_hit
    
    mov w0, #0              // false
    str w0, [x21, #28]      // hit->active = false
    
.Lupdate_next_hit:
    add w20, w20, #1        // i++
    b .Lupdate_hit_loop
    
.Lupdate_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// Draw all active bass hits
// void draw_bass_hits(uint32_t *pixels, int frame)
// Input: x0=pixels, w1=frame
.global _draw_bass_hits_asm
_draw_bass_hits_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0             // pixels
    mov w20, w1             // frame
    
    // Check if initialized
    adrp x0, bass_hits_initialized@PAGE
    add x0, x0, bass_hits_initialized@PAGEOFF
    ldrb w1, [x0]
    cmp w1, #0
    b.eq .Ldraw_done        // Return if not initialized
    
    // Calculate center: cx = VIS_WIDTH / 2, cy = VIS_HEIGHT / 2
    mov w21, #400           // cx = 800 / 2 = 400
    mov w22, #300           // cy = 600 / 2 = 300
    
    // Get bass hits array pointer
    adrp x23, bass_hits_array@PAGE
    add x23, x23, bass_hits_array@PAGEOFF
    mov w24, #0             // i = 0
    
.Ldraw_hit_loop:
    cmp w24, #16            // MAX_BASS_HITS = 16
    b.ge .Ldraw_done
    
    // Get pointer to bass_hits[i]
    mov w0, #32             // sizeof(bass_hit_t) = 32
    mul w1, w24, w0         // i * 32
    add x0, x23, w1, uxtw   // hit = &bass_hits[i]
    
    // Check if active and visible: if (!hit->active || hit->alpha <= 0) continue
    ldr w1, [x0, #28]       // Load active flag
    cmp w1, #0
    b.eq .Ldraw_next_hit    // Skip if not active
    
    ldr w1, [x0, #8]        // Load alpha
    cmp w1, #0
    b.le .Ldraw_next_hit    // Skip if alpha <= 0
    
    // Calculate size: int size = (int)(hit->max_size * fminf(hit->scale, 1.0f))
    ldr s0, [x0, #16]       // Load max_size (offset 16)
    ldr s1, [x0, #12]       // Load scale (offset 12)
    adr x1, .Lconst_1_0
    ldr s2, [x1]            // 1.0f
    fcmp s1, s2
    fcsel s1, s1, s2, le    // s1 = fminf(scale, 1.0f)
    fmul s0, s0, s1         // max_size * scale
    fcvtzs w2, s0           // Convert to int size
    
    // Get color: uint32_t color = color_to_pixel(hit->color)
    add x1, x0, #4          // pointer to hit->color (offset 4)
    stp x0, x1, [sp, #64]   // Save hit pointer and color pointer
    str w2, [sp, #72]       // Save size
    mov x0, x1              // color pointer
    bl _color_to_pixel
    mov w3, w0              // color result
    ldp x0, x1, [sp, #64]   // Restore pointers
    ldr w2, [sp, #72]       // Restore size
    
    // Get other parameters
    ldr w4, [x0, #8]        // alpha
    ldr s0, [x0, #20]       // rotation
    ldr w5, [x0]            // shape_type
    
    // Set up function call parameters in correct order
    mov x0, x19             // pixels
    mov w1, w21             // cx  
    mov w2, w22             // cy
    // Move parameters to correct registers (do in reverse order to avoid overwriting)
    mov w5, w4              // alpha (w4 -> w5)
    mov w4, w3              // color (w3 -> w4)  
    mov w3, w2              // size (w2 -> w3)
    // s0 already has rotation  
    mov w6, w20             // frame
    
    // Call appropriate shape function based on shape_type
    cmp w5, #0              // BASS_TRIANGLE = 0
    b.eq .Ldraw_triangle
    cmp w5, #1              // BASS_DIAMOND = 1
    b.eq .Ldraw_diamond
    cmp w5, #2              // BASS_HEXAGON = 2
    b.eq .Ldraw_hexagon
    cmp w5, #3              // BASS_STAR = 3
    b.eq .Ldraw_star
    cmp w5, #4              // BASS_SQUARE = 4
    b.eq .Ldraw_square
    b .Ldraw_next_hit       // Unknown shape type
    
.Ldraw_triangle:
    bl _draw_ascii_triangle_asm
    b .Ldraw_next_hit
    
.Ldraw_diamond:
    bl _draw_ascii_diamond_asm
    b .Ldraw_next_hit
    
.Ldraw_hexagon:
    bl _draw_ascii_hexagon_asm
    b .Ldraw_next_hit
    
.Ldraw_star:
    bl _draw_ascii_star_asm
    b .Ldraw_next_hit
    
.Ldraw_square:
    bl _draw_ascii_square_asm
    b .Ldraw_next_hit
    
.Ldraw_next_hit:
    add w24, w24, #1        // i++
    b .Ldraw_hit_loop
    
.Ldraw_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// All character arrays and constants
.align 1
.Lhex_chars:
    .byte 'O', '0', '#', '*', '+', 'X'

.Lsquare_chars:
    .byte '#', '=', '+', 'H', 'M', 'W'

.Ltriangle_chars:
    .byte '^', 'A', '/', '\\', '-'

.Ldiamond_chars:
    .byte '<', '>', '^', 'v', '*'

.Lstar_chars:
    .byte '*', '+', 'x', 'X', '^', 'v', '<', '>'

// All floating point constants
.align 4
.Lconst_pi_3:
    .float 1.047198         // M_PI / 3.0f
.Lconst_0_7:
    .float 0.7
.Lconst_2pi_3:
    .float 2.094395         // 2.0f * M_PI / 3.0f
.Lconst_0_8:
    .float 0.8
.Lconst_pi_5:
    .float 0.628318         // M_PI / 5.0f
.Lconst_0_15:
    .float 0.15
.Lconst_1000:
    .float 1000.0
