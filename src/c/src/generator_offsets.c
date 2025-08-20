/* generator_offsets.c - Generate ASM constants for struct offsets */
#include <stddef.h>
#include "generator.h"

#define OFF(sym, type, member) \
    asm(".equ " #sym ", %0" :: "i"(offsetof(type, member)));

void generator_offsets(void) {
    OFF(G_OFF_KICK       , generator_t, kick)
    OFF(G_OFF_SNARE      , generator_t, snare)
    OFF(G_OFF_HAT        , generator_t, hat)
    OFF(G_OFF_MELODY     , generator_t, mel)
    OFF(G_OFF_MID_FM     , generator_t, mid_fm)
    OFF(G_OFF_BASS_FM    , generator_t, bass_fm)
    OFF(G_OFF_EVQ        , generator_t, q)
    OFF(G_OFF_EV_COUNT   , generator_t, q.count)
    OFF(G_OFF_EVENT_IDX  , generator_t, event_idx)
    OFF(G_OFF_STEP       , generator_t, step)
    OFF(G_OFF_POS_IN_STEP, generator_t, pos_in_step)
    OFF(G_OFF_DELAY      , generator_t, delay)
    OFF(G_OFF_LIMITER    , generator_t, limiter)
}
