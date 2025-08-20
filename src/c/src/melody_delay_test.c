#include "wav_writer.h"
#include "melody.h"
#include "delay.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

int main(void)
{
    const uint32_t sr = 44100;
    const uint32_t total_frames = sr * 8; // 8 seconds
    float *L = calloc(total_frames, sizeof(float));
    float *R = calloc(total_frames, sizeof(float));

    // Initialize melody
    melody_t melody; 
    melody_init(&melody, (float)sr);
    
    // Initialize delay
    delay_t delay;
    const uint32_t max_delay_samples = 106000;
    float *delay_buf = calloc(max_delay_samples * 2, sizeof(float));
    delay_init(&delay, delay_buf, max_delay_samples);
    
    // Trigger melody notes with gaps for delay to be heard
    printf("Triggering melody notes with delay processing...\n");
    
    // Note 1: 440Hz at start (0.5s duration)
    melody_trigger(&melody, 440.0f, 0.5f);
    for(uint32_t i = 0; i < sr/2 && i < total_frames; i++) {
        if(melody.pos < melody.len) {
            melody_process(&melody, &L[i], &R[i], 1);
        }
    }
    
    // Note 2: 554Hz at 2 seconds (0.5s duration)
    melody_trigger(&melody, 554.37f, 0.5f);
    for(uint32_t i = sr*2; i < sr*2 + sr/2 && i < total_frames; i++) {
        if(melody.pos < melody.len) {
            melody_process(&melody, &L[i], &R[i], 1);
        }
    }
    
    // Note 3: 659Hz at 4 seconds (0.5s duration)
    melody_trigger(&melody, 659.25f, 0.5f);
    for(uint32_t i = sr*4; i < sr*4 + sr/2 && i < total_frames; i++) {
        if(melody.pos < melody.len) {
            melody_process(&melody, &L[i], &R[i], 1);
        }
    }
    
    // Note 4: 880Hz at 6 seconds (0.5s duration)
    melody_trigger(&melody, 880.0f, 0.5f);
    for(uint32_t i = sr*6; i < sr*6 + sr/2 && i < total_frames; i++) {
        if(melody.pos < melody.len) {
            melody_process(&melody, &L[i], &R[i], 1);
        }
    }
    
    printf("Applying delay to melody (feedback=0.45)...\n");
    
    // Apply delay to the entire melody buffer
    delay_process_block(&delay, L, R, total_frames, 0.45f);

    /* convert to int16 wav */
    int16_t *pcm = malloc(sizeof(int16_t)*total_frames*2);
    for(uint32_t i=0; i<total_frames; i++){
        float vL=L[i]; if(vL>1) vL=1; if(vL<-1) vL=-1;
        float vR=R[i]; if(vR>1) vR=1; if(vR<-1) vR=-1;
        pcm[2*i] = (int16_t)(vL*32767);
        pcm[2*i+1] = (int16_t)(vR*32767);
    }
    write_wav("melody_delay_test.wav", pcm, total_frames, 2, sr);
    
    printf("Generated melody_delay_test.wav (8 seconds, spaced melody with delay)\n");

    free(L); free(R); free(pcm); free(delay_buf);
    return 0;
}
