#include "generator.h"
#include <string.h>
#include <math.h>
#include <stdio.h>
#include "fm_presets.h"
#include "euclid.h"

/* Helper for RNG float */
#define RNG_FLOAT(rng) ( (rng_next_u32(rng) >> 8) * (1.0f/16777216.0f) )

/* Global RMS for real-time visual feedback */
volatile float g_block_rms = 0.0f;

void generator_init(generator_t *g, uint64_t seed)
{
    memset(g, 0, sizeof(generator_t));
    g->rng = rng_seed(seed);

    /* ---- Derive per-run musical variation from seed ---- */
    uint8_t kick_hits  = 2 + (rng_next_u32(&g->rng) % 3);
    uint8_t snare_hits = 1 + (rng_next_u32(&g->rng) % 3);
    uint8_t hat_hits   = 4 + (rng_next_u32(&g->rng) % 5);
    
    float bpm = 50.0f + (RNG_FLOAT(&g->rng) * 70.0f);
    music_time_init(&g->mt, bpm);
    music_globals_init(&g->music, &g->rng);

    /* ---- Init voices ---- */
    kick_init(&g->kick, SR);
    snare_init(&g->snare, SR, seed ^ 0xABCDEF);
    hat_init(&g->hat, SR,   seed ^ 0x123456);
    melody_init(&g->mel, SR);
    fm_voice_init(&g->mid_fm, SR);
    fm_voice_init(&g->bass_fm, SR);

    /* ---- Init delay ---- */
    delay_init(&g->delay, g->delay_buf, MAX_DELAY_SAMPLES);

    /* ---- Create simple event sequence ---- */
    eq_init(&g->q);
    
    /* Simple patterns based on variations */
    uint8_t kick_pattern = (kick_hits >= 3) ? 0x91 : 0x11;  // kick on 1, and maybe 5
    uint8_t snare_pattern = (snare_hits >= 2) ? 0x44 : 0x04; // snare on 3, maybe 7
    uint8_t hat_pattern = 0xAA;  // hat on off-beats
    uint8_t melody_pattern = 0xAA; // melody on even beats
    uint8_t mid_fm_pattern = 0x88;  // mid FM on beats 4 and 8 
    uint8_t bass_fm_pattern = 0x11; // bass FM on beats 1 and 5

    for(uint32_t step = 0; step < TOTAL_STEPS; step++) {
        uint32_t t = step * g->mt.step_samples;
        
        if(kick_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_KICK, 127);
        if(snare_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_SNARE, 100);
        if(hat_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_HAT, 80);
        if(melody_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_MELODY, 100);
        if(mid_fm_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_MID, 100);
        if(bass_fm_pattern & (1 << (step % 8)))
            eq_push(&g->q, t, EVT_FM_BASS, 80);
    }
}

/* generator_process is implemented in ASM - src/asm/active/generator.s */
