#include "wav_writer.h"
#include "hat.h"
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

    hat_t hat; 
    hat_init(&hat, (float)sr, 0x12345678); // seed for noise generator
    
    // Trigger once at the beginning
    hat_trigger(&hat);
    printf("Single hat triggered, processing %u frames\n", total_frames);
    
    // Process the entire duration in one call
    hat_process(&hat, L, R, total_frames);

    /* convert to int16 wav */
    int16_t *pcm = malloc(sizeof(int16_t)*total_frames*2);
    for(uint32_t i=0;i<total_frames;i++){
        float vL=L[i]; if(vL>1) vL=1; if(vL<-1) vL=-1;
        pcm[2*i] = (int16_t)(vL*32767);
        pcm[2*i+1] = pcm[2*i];
    }
    write_wav("hat_single.wav", pcm, total_frames, 2, sr);
    
    printf("Generated hat_single.wav (1 second, single hat)\n");

    free(L);free(R);free(pcm);
    return 0;
}
