#include "snare.h"
#include <math.h>

#define SNARE_DECAY_RATE 35.0f
#define SNARE_DUR_SEC 0.1f

void snare_init(snare_t *s, float32_t sr, uint64_t seed)
{
    s->len = 0;
    s->pos = 0;
    s->sr = sr;
    s->env = 0.0f;
    s->env_coef = 0.0f;
    s->rng = rng_seed(seed);
}

void snare_trigger(snare_t *s)
{
    s->pos = 0;
    s->len = (uint32_t)(SNARE_DUR_SEC * s->sr);
    s->env = 1.0f;
    s->env_coef = expf(-SNARE_DECAY_RATE / s->sr);
}

/* NO snare_process - ASM implementation required */
