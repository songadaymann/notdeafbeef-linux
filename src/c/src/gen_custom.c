#include "wav_writer.h"
#include "kick.h"
#include "snare.h"
#include "hat.h"
#include "melody.h"
#include "fm_voice.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdbool.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Usage: %s <voice1> [voice2] ...\n", argv[0]);
        printf("Available voices: kick, snare, hat, melody, fm\n");
        printf("Examples:\n");
        printf("  %s kick\n", argv[0]);
        printf("  %s kick snare hat\n", argv[0]);
        printf("  %s drums  (= kick + snare + hat)\n", argv[0]);
        return 1;
    }

    const uint32_t sr = 44100;
    const uint32_t total_frames = sr * 2; // 2 seconds
    float *L = calloc(total_frames, sizeof(float));
    float *R = calloc(total_frames, sizeof(float));

    // Initialize voices
    kick_t kick; kick_init(&kick, (float)sr);
    snare_t snare; snare_init(&snare, (float)sr, 0x12345678);
    hat_t hat; hat_init(&hat, (float)sr, 0x87654321);
    melody_t melody; melody_init(&melody, (float)sr);
    fm_voice_t fm; fm_voice_init(&fm, (float)sr);
    
    // Parse arguments to determine which voices to enable
    bool enable_kick = false, enable_snare = false, enable_hat = false;
    bool enable_melody = false, enable_fm = false;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "kick") == 0) enable_kick = true;
        else if (strcmp(argv[i], "snare") == 0) enable_snare = true;
        else if (strcmp(argv[i], "hat") == 0) enable_hat = true;
        else if (strcmp(argv[i], "melody") == 0) enable_melody = true;
        else if (strcmp(argv[i], "fm") == 0) enable_fm = true;
        else if (strcmp(argv[i], "drums") == 0) {
            enable_kick = enable_snare = enable_hat = true;
        }
        else {
            printf("Unknown voice: %s\n", argv[i]);
            return 1;
        }
    }
    
    printf("Testing voices: ");
    if (enable_kick) printf("kick ");
    if (enable_snare) printf("snare ");
    if (enable_hat) printf("hat ");
    if (enable_melody) printf("melody ");
    if (enable_fm) printf("fm ");
    printf("\n");

    // Trigger voices at different times
    uint32_t triggers[] = {0, sr/2, sr, sr*3/2}; // 0, 0.5, 1.0, 1.5 seconds
    
    for (uint32_t frame = 0; frame < total_frames; frame += 256) {
        // Check for triggers
        for (int t = 0; t < 4; t++) {
            if (frame == triggers[t]) {
                if (enable_kick) { kick_trigger(&kick); printf("Kick trigger at %.1fs\n", (float)frame/sr); }
                if (enable_snare) { snare_trigger(&snare); printf("Snare trigger at %.1fs\n", (float)frame/sr); }
                if (enable_hat) { hat_trigger(&hat); printf("Hat trigger at %.1fs\n", (float)frame/sr); }
                if (enable_melody) { 
                    melody_trigger(&melody, 440.0f, 0.5f); 
                    printf("Melody trigger at %.1fs\n", (float)frame/sr); 
                }
                if (enable_fm) {
                    fm_voice_trigger(&fm, 220.0f, 0.8f, 2.0f, 3.0f, 0.5f, 5.0f);
                    printf("FM trigger at %.1fs\n", (float)frame/sr);
                }
            }
        }
        
        uint32_t block = (frame + 256 <= total_frames) ? 256 : (total_frames - frame);
        
        // Process enabled voices
        if (enable_kick) kick_process(&kick, &L[frame], &R[frame], block);
        if (enable_snare) snare_process(&snare, &L[frame], &R[frame], block);
        if (enable_hat) hat_process(&hat, &L[frame], &R[frame], block);
        if (enable_melody) melody_process(&melody, &L[frame], &R[frame], block);
        if (enable_fm) fm_voice_process(&fm, &L[frame], &R[frame], block);
    }

    // Convert to WAV
    int16_t *pcm = malloc(sizeof(int16_t)*total_frames*2);
    for(uint32_t i=0;i<total_frames;i++){
        float vL=L[i]; if(vL>1) vL=1; if(vL<-1) vL=-1;
        pcm[2*i] = (int16_t)(vL*32767);
        pcm[2*i+1] = pcm[2*i];
    }
    write_wav("custom_test.wav", pcm, total_frames, 2, sr);
    
    printf("Generated custom_test.wav (2 seconds)\n");

    free(L);free(R);free(pcm);
    return 0;
}
