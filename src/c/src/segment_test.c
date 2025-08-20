#include "generator.h"
#include "wav_writer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Usage: %s <category1> [category2] ... [seed]\n", argv[0]);
        printf("Categories: drums, melody, fm, delay, limiter\n");
        printf("Examples:\n");
        printf("  %s drums\n", argv[0]);
        printf("  %s drums delay\n", argv[0]);
        printf("  %s drums 0x12345\n", argv[0]);
        printf("  %s drums melody delay fm limiter 0xdeadbeef\n", argv[0]);
        return 1;
    }

    // Parse which categories to enable and optional seed
    bool enable_drums = false, enable_melody = false, enable_fm = false;
    bool enable_delay = false, enable_limiter = false;
    uint64_t seed = 0xCAFEBABEULL;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "drums") == 0) enable_drums = true;
        else if (strcmp(argv[i], "melody") == 0) enable_melody = true;
        else if (strcmp(argv[i], "fm") == 0) enable_fm = true;
        else if (strcmp(argv[i], "delay") == 0) enable_delay = true;
        else if (strcmp(argv[i], "limiter") == 0) enable_limiter = true;
        else if (argv[i][0] == '0' && (argv[i][1] == 'x' || argv[i][1] == 'X')) {
            // Parse hex seed
            seed = strtoull(argv[i], NULL, 0);
        }
        else {
            printf("Unknown category or invalid seed: %s\n", argv[i]);
            return 1;
        }
    }
    
    printf("Generating segment with: ");
    if (enable_drums) printf("drums ");
    if (enable_melody) printf("melody ");
    if (enable_fm) printf("fm ");
    if (enable_delay) printf("delay ");
    if (enable_limiter) printf("limiter ");
    printf("\n");

    const uint32_t sr = 44100;
    generator_t g;
    generator_init(&g, seed);

    // Calculate total frames (same as segment.c)
    uint32_t total_frames = g.mt.seg_frames;
    printf("Total duration: %.2f sec (%u frames)\n", g.mt.seg_sec, total_frames);

    float *L = calloc(total_frames, sizeof(float));
    float *R = calloc(total_frames, sizeof(float));

    // Generate the audio using the same process as segment.c
    // but with selective voice processing
    for (uint32_t frame = 0; frame < total_frames; ) {
        uint32_t remaining = total_frames - frame;
        uint32_t block_size = (remaining > 1024) ? 1024 : remaining;
        
        // Trigger events (always run this to advance timing)
        generator_trigger_step(&g);
        
        // Process voices selectively
        float *block_L = &L[frame];
        float *block_R = &R[frame];
        
        // Clear the block
        memset(block_L, 0, block_size * sizeof(float));
        memset(block_R, 0, block_size * sizeof(float));
        
        if (enable_drums) {
            kick_process(&g.kick, block_L, block_R, block_size);
            snare_process(&g.snare, block_L, block_R, block_size);
            hat_process(&g.hat, block_L, block_R, block_size);
        }
        
        if (enable_melody) {
            melody_process(&g.mel, block_L, block_R, block_size);
        }
        
        if (enable_fm) {
            fm_voice_process(&g.mid_fm, block_L, block_R, block_size);
            fm_voice_process(&g.bass_fm, block_L, block_R, block_size);
        }
        
        if (enable_delay) {
            delay_process_block(&g.delay, block_L, block_R, block_size, 0.45f);
        }
        
        if (enable_limiter) {
            limiter_process(&g.limiter, block_L, block_R, block_size);
        }
        
        // Advance timing manually (since we're not using generator_process)
        g.pos_in_step += block_size;
        if (g.pos_in_step >= g.mt.step_samples) {
            g.pos_in_step = 0;
            g.step++;
        }
        
        frame += block_size;
    }

    // Convert to int16 WAV
    int16_t *pcm = malloc(sizeof(int16_t) * total_frames * 2);
    for (uint32_t i = 0; i < total_frames; i++) {
        float vL = L[i]; if(vL > 1) vL = 1; if(vL < -1) vL = -1;
        float vR = R[i]; if(vR > 1) vR = 1; if(vR < -1) vR = -1;
        pcm[2*i] = (int16_t)(vL * 32767);
        pcm[2*i+1] = (int16_t)(vR * 32767);
    }
    
    char filename[64];
    snprintf(filename, sizeof(filename), "segment_test_0x%llx.wav", (unsigned long long)seed);
    write_wav(filename, pcm, total_frames, 2, sr);
    printf("Generated %s\n", filename);

    free(L); free(R); free(pcm);
    return 0;
}
