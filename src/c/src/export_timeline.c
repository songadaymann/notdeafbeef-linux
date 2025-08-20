
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <inttypes.h>

#include "generator.h"
#include "music_time.h"
#include "event_queue.h"

static const char *event_type_to_string(uint8_t t) {
    switch ((event_type_t)t) {
        case EVT_KICK:    return "kick";
        case EVT_SNARE:   return "snare";
        case EVT_HAT:     return "hat";
        case EVT_MELODY:  return "melody";
        case EVT_MID:     return "mid";
        case EVT_FM_BASS: return "fm_bass";
        default:          return "unknown";
    }
}

int main(int argc, char **argv) {
    uint64_t seed = 0xCAFEBABEULL;
    const char *out_path = "timeline.json";

    if (argc >= 2) {
        // Accept hex like 0xDEADBEEF or decimal
        seed = strtoull(argv[1], NULL, 0);
    }
    if (argc >= 3) {
        out_path = argv[2];
    }

    generator_t g;
    generator_init(&g, seed);

    FILE *f = fopen(out_path, "wb");
    if (!f) {
        fprintf(stderr, "Failed to open %s for writing\n", out_path);
        return 1;
    }

    // Header
    fprintf(f, "{\n");
    fprintf(f, "  \"seed\": \"0x%016" PRIx64 "\",\n", seed);
    fprintf(f, "  \"sample_rate\": %u,\n", SR);
    fprintf(f, "  \"bpm\": %.6f,\n", g.mt.bpm);
    fprintf(f, "  \"step_samples\": %u,\n", g.mt.step_samples);
    fprintf(f, "  \"total_samples\": %u,\n", g.mt.seg_frames);

    // Steps array (every 16th note)
    fprintf(f, "  \"steps\": [");
    for (uint32_t s = 0; s < TOTAL_STEPS; ++s) {
        uint32_t t = s * g.mt.step_samples;
        fprintf(f, "%s%u", (s == 0 ? "" : ","), t);
    }
    fprintf(f, "],\n");

    // Beats array (every 4 steps)
    uint32_t total_beats = TOTAL_STEPS / STEPS_PER_BEAT;
    fprintf(f, "  \"beats\": [");
    for (uint32_t b = 0; b < total_beats; ++b) {
        uint32_t t = (b * STEPS_PER_BEAT) * g.mt.step_samples;
        fprintf(f, "%s%u", (b == 0 ? "" : ","), t);
    }
    fprintf(f, "],\n");

    // Events
    fprintf(f, "  \"events\": [\n");
    for (uint32_t i = 0; i < g.q.count; ++i) {
        const event_t *ev = &g.q.events[i];
        fprintf(f,
                "    {\"time\": %u, \"type\": \"%s\", \"aux\": %u}%s\n",
                ev->time,
                event_type_to_string(ev->type),
                (unsigned)ev->aux,
                (i + 1 < g.q.count ? "," : ""));
    }
    fprintf(f, "  ]\n");

    fprintf(f, "}\n");
    fclose(f);

    printf("Exported timeline to %s (bpm=%.3f, steps=%u, events=%u)\n",
           out_path, g.mt.bpm, TOTAL_STEPS, g.q.count);
    return 0;
}



