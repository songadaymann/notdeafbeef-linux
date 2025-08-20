
#include "timeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* Minimal, robust-enough JSON scanner for our known format. Avoids dependencies. */

static char *read_file_all(const char *path, size_t *len_out){
    FILE *f = fopen(path, "rb");
    if(!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char*)malloc(len + 1);
    if(!buf){ fclose(f); return NULL; }
    if(fread(buf, 1, len, f) != (size_t)len){ free(buf); fclose(f); return NULL; }
    buf[len] = '\0';
    fclose(f);
    if(len_out) *len_out = (size_t)len;
    return buf;
}

static int parse_uint_array(const char *s, const char *key, uint32_t **out, uint32_t *count){
    *out = NULL; *count = 0;
    char needle[64];
    snprintf(needle, sizeof(needle), "\"%s\": [", key);
    const char *p = strstr(s, needle);
    if(!p) return 0;
    p += strlen(needle);
    // count commas
    const char *q = p;
    uint32_t n = 0;
    while(*q && *q != ']'){ if(*q == ',') n++; q++; }
    if(*q != ']') return 0;
    n = n + 1; // elements = commas + 1
    uint32_t *arr = (uint32_t*)malloc(n * sizeof(uint32_t));
    if(!arr) return 0;
    uint32_t idx = 0;
    const char *cur = p;
    while(cur < q && idx < n){
        while(cur < q && (*cur == ' ' || *cur == '\n')) cur++;
        char *endp;
        unsigned long v = strtoul(cur, &endp, 10);
        arr[idx++] = (uint32_t)v;
        cur = endp;
        const char *comma = strchr(cur, ',');
        if(comma && comma < q) cur = comma + 1; else break;
    }
    *out = arr;
    *count = idx;
    return 1;
}

static int parse_header_u32(const char *s, const char *key, uint32_t *out){
    char needle[64];
    snprintf(needle, sizeof(needle), "\"%s\": ", key);
    const char *p = strstr(s, needle);
    if(!p) return 0;
    p += strlen(needle);
    *out = (uint32_t)strtoul(p, NULL, 10);
    return 1;
}

static int parse_header_f(const char *s, const char *key, float *out){
    char needle[64];
    snprintf(needle, sizeof(needle), "\"%s\": ", key);
    const char *p = strstr(s, needle);
    if(!p) return 0;
    p += strlen(needle);
    *out = strtof(p, NULL);
    return 1;
}

static int parse_header_seed(const char *s, uint64_t *out){
    const char *p = strstr(s, "\"seed\": \"");
    if(!p) return 0;
    p += strlen("\"seed\": \"");
    char *endq = strchr(p, '\"');
    if(!endq) return 0;
    // Expect 0x... hex
    char buf[32];
    size_t len = (size_t)(endq - p);
    if(len >= sizeof(buf)) len = sizeof(buf) - 1;
    memcpy(buf, p, len); buf[len] = '\0';
    *out = strtoull(buf, NULL, 16);
    return 1;
}

bool timeline_load(const char *path, timeline_t *out){
    memset(out, 0, sizeof(*out));
    size_t len = 0; char *txt = read_file_all(path, &len);
    if(!txt) return false;
    if(!parse_header_seed(txt, &out->seed)) { free(txt); return false; }
    if(!parse_header_u32(txt, "sample_rate", &out->sample_rate)) { free(txt); return false; }
    if(!parse_header_f(txt, "bpm", &out->bpm)) { free(txt); return false; }
    if(!parse_header_u32(txt, "step_samples", &out->step_samples)) { free(txt); return false; }
    if(!parse_header_u32(txt, "total_samples", &out->total_samples)) { free(txt); return false; }
    if(!parse_uint_array(txt, "steps", &out->steps, &out->steps_count)) { free(txt); return false; }
    if(!parse_uint_array(txt, "beats", &out->beats, &out->beats_count)) { free(txt); return false; }

    // Parse events array minimally: scan lines with {"time": X, "type": "name", "aux": Y}
    const char *evs = strstr(txt, "\"events\": [");
    if(!evs){ free(txt); return false; }
    evs += strlen("\"events\": [");
    const char *end = strstr(evs, "]");
    if(!end){ free(txt); return false; }

    // Rough count '{'
    uint32_t count = 0; for(const char *p = evs; p < end; ++p){ if(*p == '{') count++; }
    tl_event_t *events = (tl_event_t*)calloc(count, sizeof(tl_event_t));
    if(!events){ free(txt); return false; }

    const char *p = evs; uint32_t idx = 0;
    while(p < end && idx < count){
        const char *obj = strchr(p, '{');
        if(!obj || obj >= end) break;
        const char *obj_end = strchr(obj, '}'); if(!obj_end || obj_end > end) break;
        // time
        const char *tkey = strstr(obj, "\"time\": ");
        const char *typekey = strstr(obj, "\"type\": \"");
        const char *auxkey = strstr(obj, "\"aux\": ");
        if(tkey && typekey && auxkey && tkey < obj_end && typekey < obj_end && auxkey < obj_end){
            uint32_t time = (uint32_t)strtoul(tkey + 8, NULL, 10);
            const char *ts = typekey + 9; const char *te = strchr(ts, '\"');
            char tbuf[32]; size_t tlen = (size_t)(te - ts); if(tlen >= sizeof(tbuf)) tlen = sizeof(tbuf)-1; memcpy(tbuf, ts, tlen); tbuf[tlen] = '\0';
            uint8_t type = 255;
            if(strcmp(tbuf, "kick")==0) type = 0; else if(strcmp(tbuf, "snare")==0) type = 1; else if(strcmp(tbuf, "hat")==0) type = 2; else if(strcmp(tbuf, "melody")==0) type = 3; else if(strcmp(tbuf, "mid")==0) type = 4; else if(strcmp(tbuf, "fm_bass")==0) type = 5; else type = 254;
            uint8_t aux = (uint8_t)strtoul(auxkey + 7, NULL, 10);
            events[idx++] = (tl_event_t){ time, type, aux };
        }
        p = obj_end + 1;
    }
    out->events = events; out->events_count = idx;
    free(txt);
    return true;
}

void timeline_free(timeline_t *t){
    if(!t) return;
    free(t->steps); t->steps = NULL; t->steps_count = 0;
    free(t->beats); t->beats = NULL; t->beats_count = 0;
    free(t->events); t->events = NULL; t->events_count = 0;
}

/* Simple derived signals, mapped to 60 FPS. */
static float exp_env(float dt, float tau){ return expf(-dt / fmaxf(1e-6f, tau)); }

float timeline_compute_level(const timeline_t *t, int frame_idx, int fps){
    if(!t) return 0.0f;
    float sec = (float)frame_idx / (float)fps;
    // Accumulate simple decays from recent kick + snare events
    float level = 0.0f;
    for(uint32_t i=0;i<t->events_count;i++){
        uint8_t type = t->events[i].type;
        if(type > 5) continue;
        if(type==0 || type==1){ // kick/snare
            float esec = (float)t->events[i].time / (float)t->sample_rate;
            float dt = sec - esec; if(dt < 0) continue;
            float amp = (type==0)? 1.0f : 0.6f;
            level += amp * exp_env(dt, 0.2f);
        }
    }
    if(level > 1.0f) level = 1.0f;
    return level;
}

float timeline_compute_glitch(const timeline_t *t, int frame_idx, int fps){
    if(!t) return 0.3f;
    float sec = (float)frame_idx / (float)fps;
    float g = 0.2f + 0.3f * sinf(sec * 3.0f);
    // add treble-ish spikes from hat/melody
    for(uint32_t i=0;i<t->events_count;i++){
        uint8_t type = t->events[i].type;
        if(type==2 || type==3){
            float esec = (float)t->events[i].time / (float)t->sample_rate;
            float dt = sec - esec; if(dt < 0) continue;
            g += 0.1f * exp_env(dt, 0.08f);
        }
    }
    if(g < 0.0f) g = 0.0f; if(g > 1.5f) g = 1.5f;
    return g;
}

float timeline_compute_hue(const timeline_t *t, int frame_idx, int fps){
    if(!t) return 0.5f;
    float base = fmodf((float)frame_idx / (float)fps * 0.1f, 1.0f);
    // small hue jumps on bass
    for(uint32_t i=0;i<t->events_count;i++){
        if(t->events[i].type==5){
            float esec = (float)t->events[i].time / (float)t->sample_rate;
            float dt = ((float)frame_idx / (float)fps) - esec; if(dt < 0) continue;
            base += 0.05f * exp_env(dt, 0.4f);
        }
    }
    base = fmodf(base, 1.0f);
    if(base < 0) base += 1.0f;
    return base;
}



