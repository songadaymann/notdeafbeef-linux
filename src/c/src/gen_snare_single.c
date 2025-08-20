#include "wav_writer.h"
#include "snare.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

int main(void)
{
    const uint32_t sr = 44100;
    const uint32_t total_frames = sr * 1; // 1 second
    float *L = calloc(total_frames, sizeof(float));
    float *R = calloc(total_frames, sizeof(float));

    snare_t snare; 
    snare_init(&snare, (float)sr, 0x87654321); // seed for noise generator
    
    // Trigger once at the beginning
    snare_trigger(&snare);
    printf("Single snare triggered, processing %u frames\n", total_frames);
    
    // Process the entire duration in one call
    snare_process(&snare, L, R, total_frames);

    /* convert to int16 wav */
    int16_t *pcm = malloc(sizeof(int16_t)*total_frames*2);
    for(uint32_t i=0;i<total_frames;i++){
        float vL=L[i]; if(vL>1) vL=1; if(vL<-1) vL=-1;
        pcm[2*i] = (int16_t)(vL*32767);
        pcm[2*i+1] = pcm[2*i];
    }
    write_wav("snare_single.wav", pcm, total_frames, 2, sr);
    
    printf("Generated snare_single.wav (1 second, single snare)\n");

    free(L);free(R);free(pcm);
    return 0;
}
