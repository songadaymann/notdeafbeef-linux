
#include "kick.h"
#include <math.h>
#include <assert.h>
#include <stdio.h>

#define KICK_BASE_FREQ 70.0f
#define TAU (2.0f * M_PI)

void kick_init(kick_t *k, float32_t sr)
{
    k->sr = sr;
    k->pos = k->len;  // initially inactive
    
    /* Compute recurrence coefficients for sine oscillator */
    float32_t delta = TAU * KICK_BASE_FREQ / k->sr;
    k->k1 = 2.0f * cosf(delta);
    
    /* Reset sine recurrence state */
    k->y_prev  = 0.0f;            /* sin(0) */
    k->y_prev2 = -sinf(delta);    /* y[-1] = -sin(Δ) */
}

void kick_trigger(kick_t *k)
{
    k->pos = 0;
    k->env = 1.0f;
    k->len = (uint32_t)(k->sr * 0.5f);  // 500ms duration
    k->env_coef = powf(0.001f, 1.0f / k->len);  // -60dB envelope

    /* Reset sine recurrence state */
    float32_t delta = TAU * KICK_BASE_FREQ / k->sr;
    k->y_prev  = 0.0f;            /* sin(0) */
    k->y_prev2 = -sinf(delta);    /* y[-1] = -sin(Δ) */
    
#ifndef REALTIME_MODE
    printf("*** KICK_TRIGGER: len=%u env_coef=%f y_prev2=%f k1=%f ***\n", 
           k->len, k->env_coef, k->y_prev2, k->k1);
    fflush(stdout);
#endif
}

/* NO kick_process - ASM implementation required */
