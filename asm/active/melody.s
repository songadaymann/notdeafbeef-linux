
	.text
	.align 2
	.globl _melody_process

// Simplified melody implementation avoiding libm calls
// Uses polynomial approximation for exponential decay
melody_constants:
    .float 6.2831853071795864769      // [0] TAU
    .float 5.0                        // [4] DECAY_RATE  
    .float 0.07                       // [8] AMP
    .float 2.0                        // [12] TWO
    .float 1.0                        // [16] ONE
    .float 1.2                        // [20] DRIVE_GAIN
    .float 1.5                        // [24] SOFT_A
    .float 0.5                        // [28] SOFT_B

_melody_process:
    // Prologue - simpler frame
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]

    // Save arguments
    mov x19, x0      // melody*
    mov x23, x1      // L*
    mov x24, x2      // R*
    mov w22, w3      // n

    // Load melody struct members
    ldr s0, [x19]        // phase
    ldr w20, [x19, #4]   // pos
    ldr w21, [x19, #8]   // len
    ldr s1, [x19, #12]   // sr
    ldr s2, [x19, #16]   // freq

    // Early exit checks
    cmp w20, w21
    b.ge Ldone
    cbz w22, Ldone

    // Load constants
    adrp x4, melody_constants@PAGE
    add  x4, x4, melody_constants@PAGEOFF
    ldr  s10, [x4]       // TAU
    ldr  s11, [x4, #4]   // DECAY_RATE
    ldr  s12, [x4, #8]   // AMP
    ldr  s13, [x4, #12]  // TWO
    ldr  s14, [x4, #16]  // ONE
    ldr  s15, [x4, #20]  // DRIVE_GAIN
    ldr  s16, [x4, #24]  // SOFT_A
    ldr  s17, [x4, #28]  // SOFT_B

    // Calculate phase increment: TAU * freq / sr
    fmul s3, s10, s2     // TAU * freq
    fdiv s3, s3, s1      // / sr -> phase_inc in s3

    mov w4, wzr          // loop counter i

Lloop:
    // Loop bounds check
    cmp w4, w22
    b.ge Lend
    cmp w20, w21
    b.ge Lend

    // Calculate time: t = pos / sr
    ucvtf s4, w20
    fdiv s4, s4, s1      // t in s4

    // Simple exponential decay approximation: env = 1.0 / (1.0 + decay_rate * t)
    fmul s5, s11, s4     // decay_rate * t
    fadd s5, s14, s5     // 1.0 + decay_rate * t
    fdiv s5, s14, s5     // env = 1.0 / (1.0 + decay_rate * t)

    // Calculate sawtooth: frac = phase / TAU
    fdiv s6, s0, s10     // frac

    // raw = 2*frac - 1
    fmul s7, s6, s13     // 2*frac
    fsub s7, s7, s14     // -1 -> raw sawtooth

    // Apply drive: driven = 1.2 * raw
    fmul s8, s15, s7     // driven

    // Soft clipping: soft = 1.5*driven - 0.5*driven^3
    fmul s9, s8, s8      // driven^2
    fmul s9, s9, s8      // driven^3
    fmul s18, s16, s8    // 1.5*driven
    fmul s19, s17, s9    // 0.5*driven^3
    fsub s18, s18, s19   // soft = 1.5*driven - 0.5*driven^3

    // Final sample: sample = soft * env * amp
    fmul s18, s18, s5    // * env
    fmul s18, s18, s12   // * amp

    // Add to L[i] and R[i]
    ldr s19, [x23, w4, sxtw #2]
    fadd s19, s19, s18
    str s19, [x23, w4, sxtw #2]

    ldr s19, [x24, w4, sxtw #2]
    fadd s19, s19, s18
    str s19, [x24, w4, sxtw #2]

    // Update counters and phase
    add w4, w4, #1       // i++
    add w20, w20, #1     // pos++
    fadd s0, s0, s3      // phase += phase_inc

    // Wrap phase properly in both directions
    fcmp s0, s10
    b.lt .check_negative_wrap
    fsub s0, s0, s10     // phase -= TAU if phase >= TAU
    b Lloop

.check_negative_wrap:
    fmov s16, wzr        // 0.0
    fcmp s0, s16
    b.ge Lloop
    fadd s0, s0, s10     // phase += TAU if phase < 0
    b Lloop

Lend:
    // Store back state
    str s0, [x19]        // phase
    str w20, [x19, #4]   // pos

Ldone:
    // Epilogue
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
