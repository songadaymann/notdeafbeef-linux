
//==============================================================================
// Particles System - ARM64 Assembly Implementation
//
// Port of particles.c to pure ARM64 assembly
// Functions for physics-based particle effects
//==============================================================================

.text
.align 4

//==============================================================================
// Constants
//==============================================================================
particle_constants:
max_particles:          .word 256
particle_spawn_count:   .word 20
char_count:            .word 47
vis_width:             .word 800
vis_height:            .word 600
gravity_int:           .word 0x3DCCCCCD    // 0.1f as IEEE 754 float

//==============================================================================
// Read-only data
//==============================================================================
.align 4

// SAW_STEPS array (read-only)
saw_steps:
    .word 0, 8, 16, 24
saw_steps_count: .word 4

// Character set for particles (read-only)
particle_chars:
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*+-=?\0"

//==============================================================================
// Mutable data section - writable memory
//==============================================================================
.section __DATA,__data
.align 5                        // 32-byte alignment

.global particles_array
particles_array:
    .space (256 * 32), 0       // 256 particles, 32 bytes each = 8KB

particles_initialized:
    .word 0

last_step:
    .word -1

.text  // Return to text section for function definitions

//==============================================================================
// External function declarations
//==============================================================================
// From visual_core.s
.extern _hsv_to_rgb
.extern _color_to_pixel

// From ascii_renderer.s  
.extern _draw_ascii_char_asm

//==============================================================================
// void init_particles_asm(void)
//
// Initialize particle system
//==============================================================================
.align 4
.global _init_particles_asm
_init_particles_asm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    
    // Check if already initialized
    adrp x0, particles_initialized@PAGE
    add x0, x0, particles_initialized@PAGEOFF
    ldr w1, [x0]
    cbnz w1, .Lip_return
    
    // Clear all particles (set active = false)
    adrp x0, particles_array@PAGE
    add x0, x0, particles_array@PAGEOFF
    mov w1, #256                // MAX_PARTICLES
    mov w2, #32                 // Size per particle (aligned)
    
.Lip_clear_loop:
    cbz w1, .Lip_done_clear
    
    // Set active flag (offset +29) to false
    strb wzr, [x0, #29]
    
    add x0, x0, #32             // Move to next particle
    sub w1, w1, #1
    b .Lip_clear_loop
    
.Lip_done_clear:
    // Mark as initialized
    adrp x0, particles_initialized@PAGE
    add x0, x0, particles_initialized@PAGEOFF
    mov w1, #1
    str w1, [x0]
    
.Lip_return:
    ldp x29, x30, [sp], #32
    ret

//==============================================================================
// bool is_saw_step_asm(int step)
//
// Check if step is a saw step (particle explosion trigger)
// w0: step
// Returns: w0 = 1 if saw step, 0 otherwise
//==============================================================================
.align 4
.global _is_saw_step_asm
_is_saw_step_asm:
    // step32 = step % 32
    and w0, w0, #31             // Efficient modulo 32 using bit mask
    
    // Check against SAW_STEPS array
    adr x1, saw_steps
    mov w2, #4                  // SAW_STEPS_COUNT
    
.Liss_check_loop:
    cbz w2, .Liss_not_found
    
    ldr w3, [x1], #4            // Load saw step value and advance
    cmp w0, w3
    b.eq .Liss_found
    
    sub w2, w2, #1
    b .Liss_check_loop
    
.Liss_not_found:
    mov w0, #0
    ret
    
.Liss_found:
    mov w0, #1
    ret

//==============================================================================
// void spawn_explosion_asm(float cx, float cy, float base_hue)
//
// Spawn particle explosion at given position
// s0: cx (center x)
// s1: cy (center y)  
// s2: base_hue
//==============================================================================
.align 4
.global _spawn_explosion_asm
_spawn_explosion_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    
    // Save callee-saved registers
    stp x19, x20, [sp, #16]     // 16-31
    stp x21, x22, [sp, #32]     // 32-47
    stp x23, x24, [sp, #48]     // 48-63
    stp x25, x26, [sp, #64]     // 64-79
    stp x27, x28, [sp, #80]     // 80-95
    
    // Save floating point parameters
    str s0, [sp, #88]           // cx
    str s1, [sp, #92]           // cy
    // s2 (base_hue) will be used throughout
    
    mov w19, #20                // PARTICLE_SPAWN_COUNT
    mov w20, #0                 // Loop counter i
    
.Lse_spawn_loop:
    cmp w20, w19
    b.ge .Lse_return
    
    // Find free particle slot
    adrp x21, particles_array@PAGE
    add x21, x21, particles_array@PAGEOFF
    mov w22, #256               // MAX_PARTICLES
    mov w23, #0                 // j counter
    mov x24, #-1                // slot = -1
    
.Lse_find_slot:
    cmp w23, w22
    b.ge .Lse_slot_found
    
    // Check if particle[j].active is false
    mov w25, #32                // Particle size
    mul w26, w23, w25           // j * particle_size
    add x27, x21, w26, uxtw     // &particles[j]
    ldrb w28, [x27, #29]        // Load active flag
    cbz w28, .Lse_free_slot
    
    add w23, w23, #1            // j++
    b .Lse_find_slot
    
.Lse_free_slot:
    mov x24, x27                // slot = &particles[j]
    
.Lse_slot_found:
    cmp x24, #-1
    b.eq .Lse_return            // No free slots
    
    // Calculate explosion parameters
    // angle = 2.0 * PI * i / PARTICLE_SPAWN_COUNT
    scvtf s3, w20               // Convert i to float
    fmov s4, #20.0              // PARTICLE_SPAWN_COUNT as float
    fdiv s3, s3, s4             // i / PARTICLE_SPAWN_COUNT
    
    ldr w25, =0x40C90FDB        // 2*PI as IEEE 754 float
    fmov s4, w25
    fmul s3, s3, s4             // angle = 2*PI * i / PARTICLE_SPAWN_COUNT
    
    // Calculate cos(angle) and sin(angle) - simplified approximation
    // For demo purposes, using simplified trig (could be enhanced with lookup tables)
    
    // Store particle data
    ldr s4, [sp, #88]           // cx
    str s4, [x24, #0]           // p->x = cx
    ldr s4, [sp, #92]           // cy  
    str s4, [x24, #4]           // p->y = cy
    
    // Simple velocity calculation (simplified for now)
    fmov s4, #2.0               // Base speed
    str s4, [x24, #8]           // p->vx = speed (simplified)
    fmov s4, #1.0
    str s4, [x24, #12]          // p->vy = speed (simplified)
    
    // Set life (simplified - use fixed life for now)
    mov w25, #60
    str w25, [x24, #16]         // p->life = 60
    str w25, [x24, #20]         // p->max_life = 60
    
    // Set character (simplified - use 'A' for now)
    mov w25, #65                // 'A'
    strb w25, [x24, #24]        // p->character = 'A'
    
    // Set color (simplified - use red for now)
    mov w25, #255
    strb w25, [x24, #25]        // r = 255
    strb wzr, [x24, #26]        // g = 0
    strb wzr, [x24, #27]        // b = 0
    strb w25, [x24, #28]        // a = 255
    
    // Set active = true
    mov w25, #1
    strb w25, [x24, #29]        // p->active = true
    
    add w20, w20, #1            // i++
    b .Lse_spawn_loop
    
.Lse_return:
    // Restore callee-saved registers
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

//==============================================================================
// void update_particles_asm(float elapsed_ms, float step_sec, float base_hue)
//
// Update particle physics and spawn explosions
// s0: elapsed_ms
// s1: step_sec
// s2: base_hue
//==============================================================================
.align 4
.global _update_particles_asm
_update_particles_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    
    // Save callee-saved registers
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    // Check if initialized
    adrp x19, particles_initialized@PAGE
    add x19, x19, particles_initialized@PAGEOFF
    ldr w20, [x19]
    cbz w20, .Lup_return
    
    // Calculate current step: (int)(elapsed_ms / 1000.0 / step_sec) % 32
    ldr w25, =0x447A0000        // 1000.0f as IEEE 754 float
    fmov s3, w25
    fdiv s0, s0, s3             // elapsed_ms / 1000.0
    fdiv s0, s0, s1             // / step_sec
    fcvtms w21, s0              // Convert to int
    and w21, w21, #31           // % 32
    
    // Check if this is a saw step and different from last step
    mov w0, w21
    bl _is_saw_step_asm
    cbz w0, .Lup_skip_spawn
    
    adrp x22, last_step@PAGE
    add x22, x22, last_step@PAGEOFF
    ldr w23, [x22]
    cmp w21, w23
    b.eq .Lup_skip_spawn
    
    // Update last_step
    str w21, [x22]
    
    // Spawn explosion at random position
    // cx = VIS_WIDTH * 0.3 + random * (VIS_WIDTH * 0.4)  
    // cy = VIS_HEIGHT * 0.2 + random * (VIS_HEIGHT * 0.3)
    // Simplified: use fixed position for now
    ldr w25, =0x43C80000        // 400.0f as IEEE 754 float
    fmov s0, w25                // cx = 400 (center of 800)
    ldr w25, =0x43480000        // 200.0f as IEEE 754 float
    fmov s1, w25                // cy = 200 (upper area of 600)
    // s2 already has base_hue
    bl _spawn_explosion_asm
    
.Lup_skip_spawn:
    // Update all active particles
    adrp x19, particles_array@PAGE
    add x19, x19, particles_array@PAGEOFF
    mov w20, #256               // MAX_PARTICLES
    mov w21, #0                 // Loop counter
    
.Lup_particle_loop:
    cmp w21, w20
    b.ge .Lup_return
    
    // Calculate particle pointer
    mov w22, #32                // Particle size  
    mul w23, w21, w22           // i * particle_size
    add x24, x19, w23, uxtw     // &particles[i]
    
    // Check if active
    ldrb w25, [x24, #29]
    cbz w25, .Lup_next_particle
    
    // Update physics: x += vx, y += vy, vy += gravity
    ldr s0, [x24, #0]           // x
    ldr s1, [x24, #8]           // vx
    fadd s0, s0, s1             // x += vx
    str s0, [x24, #0]
    
    ldr s0, [x24, #4]           // y
    ldr s1, [x24, #12]          // vy
    fadd s0, s0, s1             // y += vy
    str s0, [x24, #4]
    
    // vy += gravity (0.1f)
    adr x25, gravity_int
    ldr w26, [x25]
    fmov s2, w26                // Load gravity as float
    fadd s1, s1, s2             // vy += gravity
    str s1, [x24, #12]
    
    // Update life: life--
    ldr w25, [x24, #16]         // life
    sub w25, w25, #1
    str w25, [x24, #16]
    
    // Check if life expired
    cmp w25, #0
    b.gt .Lup_next_particle
    
    // Deactivate particle
    strb wzr, [x24, #29]        // active = false
    
.Lup_next_particle:
    add w21, w21, #1
    b .Lup_particle_loop
    
.Lup_return:
    // Restore callee-saved registers
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

//==============================================================================
// void draw_particles_asm(uint32_t *pixels)
//
// Draw all active particles
// x0: pixels buffer
//==============================================================================
.align 4
.global _draw_particles_asm
_draw_particles_asm:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    
    // Save callee-saved registers
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    
    mov x19, x0                 // Save pixels buffer
    
    // Check if initialized
    adrp x20, particles_initialized@PAGE
    add x20, x20, particles_initialized@PAGEOFF
    ldr w21, [x20]
    cbz w21, .Ldp_return
    
    // Loop through all particles
    adrp x20, particles_array@PAGE
    add x20, x20, particles_array@PAGEOFF
    mov w21, #256               // MAX_PARTICLES
    mov w22, #0                 // Loop counter
    
.Ldp_particle_loop:
    cmp w22, w21
    b.ge .Ldp_return
    
    // Calculate particle pointer
    mov w23, #32                // Particle size
    mul w24, w22, w23           // i * particle_size
    add x25, x20, w24, uxtw     // &particles[i]
    
    // Check if active and life > 0
    ldrb w26, [x25, #29]        // active
    cbz w26, .Ldp_next_particle
    
    ldr w26, [x25, #16]         // life
    cmp w26, #0
    b.le .Ldp_next_particle
    
    // Calculate alpha: (255 * life) / max_life
    ldr w27, [x25, #20]         // max_life
    mov w28, #255
    mul w26, w26, w28           // life * 255
    udiv w26, w26, w27          // alpha = (life * 255) / max_life
    
    // Get color components
    ldrb w1, [x25, #25]         // r
    ldrb w2, [x25, #26]         // g
    ldrb w3, [x25, #27]         // b
    ldrb w4, [x25, #28]         // a
    
    // Pack color: (a << 24) | (r << 16) | (g << 8) | b
    lsl w4, w4, #24             // a << 24
    lsl w1, w1, #16             // r << 16
    lsl w2, w2, #8              // g << 8
    orr w4, w4, w1              // Combine a and r
    orr w4, w4, w2              // Combine g
    orr w4, w4, w3              // Combine b
    
    // Call draw_ascii_char_asm
    mov x0, x19                 // pixels buffer
    ldr s1, [x25, #0]           // x position
    fcvtms w1, s1               // Convert to int
    ldr s2, [x25, #4]           // y position  
    fcvtms w2, s2               // Convert to int
    ldrb w3, [x25, #24]         // character
    // w4 already has color
    mov w5, w26                 // alpha
    bl _draw_ascii_char_asm
    
.Ldp_next_particle:
    add w22, w22, #1
    b .Ldp_particle_loop
    
.Ldp_return:
    // Restore callee-saved registers
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

//==============================================================================
// void reset_particle_step_tracking_asm(void)
//
// Reset particle step tracking
//==============================================================================
.align 4
.global _reset_particle_step_tracking_asm
_reset_particle_step_tracking_asm:
    adrp x0, last_step@PAGE
    add x0, x0, last_step@PAGEOFF
    mov w1, #-1
    str w1, [x0]
    ret
