
#include "fm_voice.h"
#include <stdio.h>

void fm_voice_init(fm_voice_t *v, float32_t sr)
{
    v->sr = sr;
    v->len = 0;
    v->pos = 0;
    v->carrier_phase = 0.0f;
    v->mod_phase = 0.0f;
}

void fm_voice_trigger(fm_voice_t *v, float32_t carrier_freq, float32_t duration_sec, float32_t ratio, float32_t index, float32_t amp, float32_t decay)
{
    v->carrier_freq = carrier_freq;
    v->ratio = ratio;
    v->index0 = index;
    v->amp = amp;
    v->decay = decay;
    v->len = (uint32_t)(duration_sec * v->sr);
    v->pos = 0;
#ifndef REALTIME_MODE
    printf("FM_TRIGGER cf=%.2f dur=%.2f ratio=%.2f idx=%.2f amp=%.2f len=%u\n", carrier_freq, duration_sec, ratio, index, amp, v->len);
#endif
}

/* When NO_C_VOICES=1: Only init/trigger stubs - no C processing fallback
 * ASM implementation required for fm_voice_process */
