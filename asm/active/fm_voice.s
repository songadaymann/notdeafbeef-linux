
	.section	__TEXT,__const
	.align 2
.L_tau:
	.float 6.283185307
.L_pi:
	.float 3.14159265
.L_six:
	.float 6.0
.L_onehundredtwenty:
	.float 120.0

	.text
	.align 2
	.globl _fm_voice_process

// fm_voice_process(fm_voice_t *v, float32_t *L, float32_t *R, uint32_t n)
// Struct offsets: sr=0, carrier_freq=4, ratio=8, index0=12, amp=16, decay=20
// len=24, pos=28, carrier_phase=32, mod_phase=36
_fm_voice_process:
    // x0 = fm_voice_t *v, x1 = L, x2 = R, x3 = n
    
    // Early exit if pos >= len
    ldr w4, [x0, #28]   // v->pos
    ldr w5, [x0, #24]   // v->len  
    cmp w4, w5
    b.ge .fm_exit
    
    // Load parameters
    ldr s16, [x0, #0]   // v->sr
    ldr s17, [x0, #4]   // v->carrier_freq
    ldr s18, [x0, #8]   // v->ratio
    ldr s19, [x0, #12]  // v->index0
    ldr s20, [x0, #16]  // v->amp
    ldr s21, [x0, #20]  // v->decay
    ldr s22, [x0, #32]  // v->carrier_phase
    ldr s23, [x0, #36]  // v->mod_phase
    
    // Calculate increments: c_inc = TAU * carrier_freq / sr
    adrp x7, .L_tau@PAGE
    add x7, x7, .L_tau@PAGEOFF
    ldr s0, [x7]           // Load TAU
    fmul s24, s0, s17      // TAU * carrier_freq
    fdiv s24, s24, s16     // c_inc = TAU * carrier_freq / sr
    
    // m_inc = TAU * carrier_freq * ratio / sr
    fmul s25, s24, s18     // m_inc = c_inc * ratio
    
    mov w6, #0             // i = 0
    
.fm_loop:
    cmp w6, w3             // i < n?
    b.ge .fm_loop_end
    
    // Check if pos >= len
    ldr w4, [x0, #28]      // v->pos
    ldr w5, [x0, #24]      // v->len
    cmp w4, w5
    b.ge .fm_loop_end
    
    // Calculate envelope: t = pos / sr
    ucvtf s26, w4          // convert pos to float
    fdiv s26, s26, s16     // t = pos / sr
    
    // Simple exponential decay approximation: env ≈ 1.0 / (1.0 + decay * t)
    fmul s27, s21, s26     // decay * t
    fmov s28, #1.0
    fadd s27, s28, s27     // 1.0 + decay * t
    fdiv s27, s28, s27     // env = 1.0 / (1.0 + decay * t)
    
    // Index with envelope: index = index0 * env
    fmul s29, s19, s27     // index = index0 * env
    
    // FM synthesis: sin(carrier_phase + index * sin(mod_phase))
    // Use polynomial approximation for sine waves
    
    // Step 1: Calculate sin(mod_phase) using polynomial approximation
    // Normalize mod_phase to [-π, π] range
    adrp x7, .L_pi@PAGE
    add x7, x7, .L_pi@PAGEOFF
    ldr s30, [x7]          // Load PI
    
    // Wrap mod_phase to [-π, π]
    fmov s31, s23          // s31 = mod_phase
    fcmp s31, s30          // compare with π
    b.le .fm_mod_no_wrap_pos
    fsub s31, s31, s30     // mod_phase - π
    fsub s31, s31, s30     // mod_phase - 2π
.fm_mod_no_wrap_pos:
    fneg s0, s30           // -π
    fcmp s31, s0           // compare with -π
    b.ge .fm_mod_wrapped
    fadd s31, s31, s30     // mod_phase + π
    fadd s31, s31, s30     // mod_phase + 2π
.fm_mod_wrapped:
    
    // Use polynomial sine approximation instead of libm for stability
    // sin(x) ≈ x - x³/6 + x⁵/120 (higher order for better accuracy)
    fmul s0, s31, s31      // x²
    fmul s1, s0, s31       // x³
    fmul s2, s0, s0        // x⁴
    fmul s3, s2, s31       // x⁵
    
    // Calculate x³/6
    adrp x7, .L_six@PAGE
    add x7, x7, .L_six@PAGEOFF
    ldr s4, [x7]
    fdiv s1, s1, s4        // x³/6
    
    // Calculate x⁵/120  
    adrp x7, .L_onehundredtwenty@PAGE
    add x7, x7, .L_onehundredtwenty@PAGEOFF
    ldr s4, [x7]
    fdiv s3, s3, s4        // x⁵/120
    
    // Combine: x - x³/6 + x⁵/120
    fsub s31, s31, s1      // x - x³/6
    fadd s31, s31, s3      // x - x³/6 + x⁵/120
    
    // Step 2: Apply modulation index: index * sin(mod_phase)
    fmul s31, s29, s31     // index * sin(mod_phase)
    
    // Clamp modulation to prevent instability: limit to [-3.0, 3.0]
    fmov s0, #3.0
    fcmp s31, s0
    b.le .fm_mod_clamp_pos_ok
    fmov s31, s0           // clamp to +3.0
.fm_mod_clamp_pos_ok:
    fneg s0, s0            // -3.0
    fcmp s31, s0
    b.ge .fm_mod_clamp_neg_ok
    fmov s31, s0           // clamp to -3.0
.fm_mod_clamp_neg_ok:
    
    // Step 3: Add to carrier phase: carrier_phase + index * sin(mod_phase)
    fadd s31, s22, s31     // carrier_phase + index * sin(mod_phase)
    
    // Step 4: Calculate final sine: sin(carrier_phase + index * sin(mod_phase))
    // Wrap result to [-π, π] range
    fcmp s31, s30          // compare with π
    b.le .fm_carr_no_wrap_pos
    fsub s31, s31, s30     // result - π
    fsub s31, s31, s30     // result - 2π
.fm_carr_no_wrap_pos:
    fneg s0, s30           // -π
    fcmp s31, s0           // compare with -π
    b.ge .fm_carr_wrapped
    fadd s31, s31, s30     // result + π
    fadd s31, s31, s30     // result + 2π
.fm_carr_wrapped:
    
    // Use higher-order polynomial sine approximation  
    // sin(x) ≈ x - x³/6 + x⁵/120 (better accuracy than simple version)
    fmul s0, s31, s31      // x²
    fmul s1, s0, s31       // x³
    fmul s2, s0, s0        // x⁴
    fmul s3, s2, s31       // x⁵
    
    // Calculate x³/6
    adrp x7, .L_six@PAGE
    add x7, x7, .L_six@PAGEOFF
    ldr s4, [x7]
    fdiv s1, s1, s4        // x³/6
    
    // Calculate x⁵/120  
    adrp x7, .L_onehundredtwenty@PAGE
    add x7, x7, .L_onehundredtwenty@PAGEOFF
    ldr s4, [x7]
    fdiv s3, s3, s4        // x⁵/120
    
    // Combine: x - x³/6 + x⁵/120
    fsub s31, s31, s1      // x - x³/6
    fadd s31, s31, s3      // x - x³/6 + x⁵/120
    // s31 now contains the final FM synthesis result
    
    // Apply envelope and amplitude (with scaling to prevent clipping)
    fmul s31, s31, s27     // apply envelope
    fmul s31, s31, s20     // apply amplitude
    fmov s0, #0.25         // Scale down to prevent clipping from FM harmonics  
    fmul s31, s31, s0      // final scaling
    
    // Final safety clamp to prevent amplitude spikes: limit to [-1.0, 1.0]
    fmov s0, #1.0
    fcmp s31, s0
    b.le .fm_out_clamp_pos_ok
    fmov s31, s0           // clamp to +1.0
.fm_out_clamp_pos_ok:
    fneg s0, s0            // -1.0
    fcmp s31, s0
    b.ge .fm_out_clamp_neg_ok
    fmov s31, s0           // clamp to -1.0
.fm_out_clamp_neg_ok:
    
    // Add to output buffers
    ldr s0, [x1, x6, lsl #2]  // L[i]
    fadd s0, s0, s31          // L[i] += sample
    str s0, [x1, x6, lsl #2]  // store L[i]
    
    ldr s0, [x2, x6, lsl #2]  // R[i]
    fadd s0, s0, s31          // R[i] += sample
    str s0, [x2, x6, lsl #2]  // store R[i]
    
    // Update phases
    fadd s22, s22, s24     // carrier_phase += c_inc
    fadd s23, s23, s25     // mod_phase += m_inc
    
    // Keep phases in range [0, TAU] with proper modulo wrapping
    adrp x7, .L_tau@PAGE
    add x7, x7, .L_tau@PAGEOFF
    ldr s0, [x7]           // Load TAU
    
    // Carrier phase proper modulo: phase = phase - TAU * round(phase / TAU)
    fdiv s1, s22, s0       // s1 = carrier_phase / TAU
    frinta s1, s1          // s1 = round(carrier_phase / TAU)
    fmul s1, s1, s0        // s1 = round(carrier_phase / TAU) * TAU
    fsub s22, s22, s1      // carrier_phase = carrier_phase - round_part
    
    // Modulator phase proper modulo: phase = phase - TAU * round(phase / TAU)  
    fdiv s2, s23, s0       // s2 = mod_phase / TAU
    frinta s2, s2          // s2 = round(mod_phase / TAU)
    fmul s2, s2, s0        // s2 = round(mod_phase / TAU) * TAU
    fsub s23, s23, s2      // mod_phase = mod_phase - round_part
    
    // Increment counters
    add w6, w6, #1         // i++
    add w4, w4, #1         // pos++
    str w4, [x0, #28]      // store v->pos
    
    b .fm_loop

.fm_loop_end:
    // Store updated phases
    str s22, [x0, #32]     // v->carrier_phase
    str s23, [x0, #36]     // v->mod_phase

.fm_exit:
    ret
