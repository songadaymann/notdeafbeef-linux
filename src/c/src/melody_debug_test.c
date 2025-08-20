
#include "melody.h"
#include "wav_writer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main(void)
{
    const uint32_t sr = 44100;
    const uint32_t test_frames = 1000; // Short test
    
    melody_t melody;
    melody_init(&melody, sr);
    
    // Trigger a melody note
    melody_trigger(&melody, 440.0f, 0.5f);
    printf("MELODY DEBUG: triggered freq=440.0 dur=0.5 len=%u pos=%u\n", melody.len, melody.pos);
    
    float *L = calloc(test_frames, sizeof(float));
    float *R = calloc(test_frames, sizeof(float));
    
    // Process just the first few frames with debug
    printf("MELODY DEBUG: Before melody_process - pos=%u len=%u\n", melody.pos, melody.len);
    
    melody_process(&melody, L, R, test_frames);
    
    printf("MELODY DEBUG: After melody_process - pos=%u len=%u\n", melody.pos, melody.len);
    
    // Check first few samples for non-zero values
    printf("MELODY DEBUG: First 10 samples:\n");
    for (int i = 0; i < 10; i++) {
        printf("  L[%d] = %f, R[%d] = %f\n", i, L[i], i, R[i]);
    }
    
    // Check for any non-zero values in the buffer
    int non_zero_count = 0;
    float max_val = 0;
    for (uint32_t i = 0; i < test_frames; i++) {
        if (L[i] != 0.0f || R[i] != 0.0f) {
            non_zero_count++;
            if (fabsf(L[i]) > max_val) max_val = fabsf(L[i]);
            if (fabsf(R[i]) > max_val) max_val = fabsf(R[i]);
        }
    }
    printf("MELODY DEBUG: Non-zero samples: %d/%u, max_val=%f\n", non_zero_count, test_frames, max_val);
    
    // Convert and save
    int16_t *pcm = malloc(sizeof(int16_t) * test_frames * 2);
    for (uint32_t i = 0; i < test_frames; i++) {
        float vL = L[i]; if(vL > 1) vL = 1; if(vL < -1) vL = -1;
        float vR = R[i]; if(vR > 1) vR = 1; if(vR < -1) vR = -1;
        pcm[2*i] = (int16_t)(vL * 32767);
        pcm[2*i+1] = (int16_t)(vR * 32767);
    }
    
    write_wav("melody_debug.wav", pcm, test_frames, 2, sr);
    printf("Generated melody_debug.wav\n");
    
    free(L); free(R); free(pcm);
    return 0;
}
