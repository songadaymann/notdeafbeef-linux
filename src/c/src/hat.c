
#include "hat.h"
#include <math.h>
#include <stdio.h>

#define HAT_DECAY_RATE 120.0f
#define HAT_DUR_SEC 0.05f

void hat_init(hat_t *h, float32_t sr, uint64_t seed)
{
    h->pos=0; h->len=0; h->sr=sr;
    h->env = 0.0f;
    h->env_coef = 0.0f;
    h->rng = rng_seed(seed);
}

void hat_trigger(hat_t *h)
{
    h->pos = 0;
    h->len = (uint32_t)(HAT_DUR_SEC * h->sr);
    h->env = 1.0f;
    h->env_coef = expf(-HAT_DECAY_RATE / h->sr);
    
#ifndef REALTIME_MODE
    printf("*** HAT_TRIGGER: len=%u env_coef=%f ***\n", 
           h->len, h->env_coef);
    fflush(stdout);
#endif
}

/* NO hat_process - ASM implementation required */
