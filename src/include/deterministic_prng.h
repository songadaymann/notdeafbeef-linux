
#ifndef DETERMINISTIC_PRNG_H
#define DETERMINISTIC_PRNG_H

#include <stdint.h>

// Simple, fast xorshift32 PRNG for deterministic generation
// Based on deafbeef-style reproducible randomness
typedef struct {
    uint32_t state;
} prng_t;

// Initialize PRNG with seed
static inline void prng_seed(prng_t* rng, uint32_t seed) {
    rng->state = seed ? seed : 1; // Ensure non-zero state
}

// Generate next random uint32
static inline uint32_t prng_next(prng_t* rng) {
    rng->state ^= rng->state << 13;
    rng->state ^= rng->state >> 17;
    rng->state ^= rng->state << 5;
    return rng->state;
}

// Generate float in [0.0, 1.0)
static inline float prng_float(prng_t* rng) {
    return (float)prng_next(rng) / (float)UINT32_MAX;
}

// Generate int in [0, max)
static inline int prng_range(prng_t* rng, int max) {
    if (max <= 0) return 0;
    return (int)(prng_next(rng) % (uint32_t)max);
}

// Global PRNG streams for different visual systems
extern prng_t g_visual_prng;      // Main visual composition
extern prng_t g_particle_prng;    // Particle system
extern prng_t g_ship_prng;        // Ship generation
extern prng_t g_boss_prng;        // Boss generation
extern prng_t g_projectile_prng;  // Projectile system
extern prng_t g_effects_prng;     // Visual effects

// Initialize all PRNG streams from base seed
void init_visual_prng_streams(uint32_t base_seed);

#endif // DETERMINISTIC_PRNG_H
