
#ifndef TIMELINE_H
#define TIMELINE_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint32_t time;   /* samples */
    uint8_t  type;   /* 0..N mapped to strings */
    uint8_t  aux;
} tl_event_t;

typedef struct {
    /* header */
    uint64_t seed;
    uint32_t sample_rate;
    float    bpm;
    uint32_t step_samples;
    uint32_t total_samples;

    /* arrays (owned) */
    uint32_t *steps;      /* length steps_count */
    uint32_t  steps_count;
    uint32_t *beats;      /* length beats_count */
    uint32_t  beats_count;
    tl_event_t *events;   /* length events_count */
    uint32_t    events_count;
} timeline_t;

/* Load a minimal JSON written by export_timeline.c.
   Returns true on success; on success, out will own allocated arrays and must be freed with timeline_free(). */
bool timeline_load(const char *path, timeline_t *out);
void timeline_free(timeline_t *t);

/* Helpers to derive frame-time signals from events (simple exponential decays). */
float timeline_compute_level(const timeline_t *t, int frame_idx, int fps);
float timeline_compute_glitch(const timeline_t *t, int frame_idx, int fps);
float timeline_compute_hue(const timeline_t *t, int frame_idx, int fps);

#endif /* TIMELINE_H */


