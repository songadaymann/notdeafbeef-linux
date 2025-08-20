#include "fm_voice.h"
#include "wav_writer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main(void)
{
    const uint32_t sr = 44100;
    const uint32_t test_frames = 5000; // Short test
    
    fm_voice_t fm;
    fm_voice_init(&fm, sr);
    
    // Trigger an FM note with higher amplitude for better audibility
    fm_voice_trigger(&fm, 440.0f, 1.0f, 2.0f, 3.0f, 1.0f, 0.5f); // freq, dur, ratio, idx, amp, decay
    printf("FM DEBUG: triggered freq=440.0 dur=1.0 ratio=2.0 idx=3.0 amp=0.5 decay=1.0\n");
    printf("FM DEBUG: len=%u pos=%u\n", fm.len, fm.pos);
    
    float *L = calloc(test_frames, sizeof(float));
    float *R = calloc(test_frames, sizeof(float));
    
    // Process just the first few frames with debug
    printf("FM DEBUG: Before fm_voice_process - pos=%u len=%u\n", fm.pos, fm.len);
    
    fm_voice_process(&fm, L, R, test_frames);
    
    printf("FM DEBUG: After fm_voice_process - pos=%u len=%u\n", fm.pos, fm.len);
    
    // Check first few samples for non-zero values
    printf("FM DEBUG: First 10 samples:\n");
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
    printf("FM DEBUG: Non-zero samples: %d/%u, max_val=%f\n", non_zero_count, test_frames, max_val);
    
    // Convert and save
    int16_t *pcm = malloc(sizeof(int16_t) * test_frames * 2);
    for (uint32_t i = 0; i < test_frames; i++) {
        float vL = L[i]; if(vL > 1) vL = 1; if(vL < -1) vL = -1;
        float vR = R[i]; if(vR > 1) vR = 1; if(vR < -1) vR = -1;
        pcm[2*i] = (int16_t)(vL * 32767);
        pcm[2*i+1] = (int16_t)(vR * 32767);
    }
    
    write_wav("fm_debug.wav", pcm, test_frames, 2, sr);
    printf("Generated fm_debug.wav\n");
    
    free(L); free(R); free(pcm);
    return 0;
}
