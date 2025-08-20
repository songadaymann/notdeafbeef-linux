#include "wav_writer.h"
#include "generator.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

/* extern counter defined in generator_step.c */
extern int g_mid_trigger_count;

// Deterministically hash a transaction hash to a 32-bit seed
// Preserves deafbeef-style reproducibility while handling long hashes
uint32_t hash_transaction_to_seed(const char* tx_hash) {
    uint32_t seed = 0;
    const char* hex_start = tx_hash;
    
    // Skip "0x" prefix if present
    if (tx_hash[0] == '0' && (tx_hash[1] == 'x' || tx_hash[1] == 'X')) {
        hex_start += 2;
    }
    
    size_t len = strlen(hex_start);
    
    // XOR all 8-character chunks together for good distribution
    for (int i = 0; i < len; i += 8) {
        char chunk[9] = {0};
        int chunk_len = (len - i >= 8) ? 8 : (len - i);
        strncpy(chunk, hex_start + i, chunk_len);
        
        // Convert hex chunk to uint32_t and XOR into seed
        uint32_t chunk_val = (uint32_t)strtoul(chunk, NULL, 16);
        seed ^= chunk_val;
    }
    
    // If seed is 0, use a fallback to avoid degenerate case
    if (seed == 0) {
        seed = 0xDEADBEEF;
    }
    
    return seed;
}

#define MAX_SEG_FRAMES 424000 
static float L[MAX_SEG_FRAMES], R[MAX_SEG_FRAMES];
static int16_t pcm[MAX_SEG_FRAMES * 2];

/* Fallback scalar RMS when assembly version not linked */
#ifndef GENERATOR_RMS_ASM_PRESENT
float generator_compute_rms_asm(const float *L, const float *R, uint32_t num_frames)
{
    double sum = 0.0;
    for(uint32_t i=0;i<num_frames;i++){
        double sL = L[i];
        double sR = R[i];
        sum += sL*sL + sR*sR;
    }
    return (float)sqrt(sum / (double)(2*num_frames));
}
#endif

int main(int argc, char **argv)
{
    uint32_t seed = 0xCAFEBABE;  // Changed to 32-bit
    if(argc > 1) {
        seed = hash_transaction_to_seed(argv[1]);  // Use hash-the-hash function
    }
    
    generator_t g;
    generator_init(&g, seed);

    uint32_t total_frames = g.mt.seg_frames;
    if(total_frames > MAX_SEG_FRAMES) total_frames = MAX_SEG_FRAMES;

    printf("C-DBG before gen_process: step_samples=%u addr=%p\n", g.mt.step_samples, &g.mt.step_samples);
    generator_process(&g, L, R, total_frames);
    
    /* RMS diagnostic to verify audio energy */
    float rms = generator_compute_rms_asm(L, R, total_frames);
    printf("C-POST rms=%f\n", rms);
    printf("DEBUG: MID triggers fired = %d\n", g_mid_trigger_count);

    for(uint32_t i=0;i<total_frames;i++){
        pcm[2*i]   = (int16_t)(L[i]*32767);
        pcm[2*i+1] = (int16_t)(R[i]*32767);
    }

    char wavname[128];  // Increased buffer for long transaction hashes
    sprintf(wavname, "seed_0x%x.wav", seed);  // Use 32-bit format
    write_wav(wavname, pcm, total_frames, 2, SR);
    printf("Wrote %s (%u frames, %.2f bpm, root %.2f Hz)\n", wavname, total_frames, g.mt.bpm, g.music.root_freq);

    return 0;
} 