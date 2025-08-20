#include "melody.h"
#include <math.h>
#include <stdio.h>

#define MELODY_MAX_SEC 2.0f

void melody_init(melody_t *m, float32_t sr)
{
    osc_reset(&m->osc);
    m->sr = sr;
    m->len = 0;
    m->pos = 0;
    m->freq = 440.0f;
}

void melody_trigger(melody_t *m, float32_t freq, float32_t dur_sec)
{
    m->freq = freq;
    m->len = (uint32_t)(dur_sec * m->sr);
    if(m->len > (uint32_t)(MELODY_MAX_SEC * m->sr))
        m->len = (uint32_t)(MELODY_MAX_SEC * m->sr);
    m->pos = 0;
#ifndef REALTIME_MODE
    printf("*** MELODY_TRIGGER: freq=%.2f dur=%.2f len=%u ***\n", freq, dur_sec, m->len);
#endif
}

/* NO melody_process - ASM implementation required */ 