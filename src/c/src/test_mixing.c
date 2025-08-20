#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// External ASM function
extern void generator_mix_buffers_asm(float *L, float *R, 
                                     const float *Ld, const float *Rd,
                                     const float *Ls, const float *Rs, 
                                     uint32_t num_frames);

int main() {
    const uint32_t frames = 1024;
    
    // Allocate aligned buffers
    float *L = malloc(frames * sizeof(float));
    float *R = malloc(frames * sizeof(float));
    float *Ld = malloc(frames * sizeof(float));
    float *Rd = malloc(frames * sizeof(float));
    float *Ls = malloc(frames * sizeof(float));
    float *Rs = malloc(frames * sizeof(float));
    
    if (!L || !R || !Ld || !Rd || !Ls || !Rs) {
        printf("MALLOC_FAILED\n");
        return 1;
    }
    
    // Initialize test data
    for (uint32_t i = 0; i < frames; i++) {
        Ld[i] = 0.1f;  // drums left
        Rd[i] = 0.1f;  // drums right
        Ls[i] = 0.2f;  // synth left
        Rs[i] = 0.2f;  // synth right
        L[i] = 0.0f;   // output left (should become 0.3)
        R[i] = 0.0f;   // output right (should become 0.3)
    }
    
    printf("BEFORE_MIX: L[0]=%f R[0]=%f\n", L[0], R[0]);
    printf("INPUTS: Ld=%f Rd=%f Ls=%f Rs=%f\n", Ld[0], Rd[0], Ls[0], Rs[0]);
    
    // Call the mixing function
    generator_mix_buffers_asm(L, R, Ld, Rd, Ls, Rs, frames);
    
    printf("AFTER_MIX: L[0]=%f R[0]=%f\n", L[0], R[0]);
    
    // Check if mixing worked correctly
    float expected = 0.1f + 0.2f; // Ld + Ls = 0.3
    if (L[0] > expected - 0.01f && L[0] < expected + 0.01f) {
        printf("MIX_SUCCESS\n");
    } else {
        printf("MIX_FAILED: expected=%f actual=%f\n", expected, L[0]);
    }
    
    free(L); free(R); free(Ld); free(Rd); free(Ls); free(Rs);
    return 0;
}
