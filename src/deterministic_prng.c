#include "include/deterministic_prng.h"

// Global PRNG streams for different visual systems
prng_t g_visual_prng;
prng_t g_particle_prng;
prng_t g_ship_prng;
prng_t g_boss_prng;
prng_t g_projectile_prng;
prng_t g_effects_prng;

void init_visual_prng_streams(uint32_t base_seed) {
    // Initialize each stream with different seeds derived from base_seed
    // Using prime number offsets to ensure good distribution
    prng_seed(&g_visual_prng, base_seed);
    prng_seed(&g_particle_prng, base_seed ^ 0x7F4A7C15);
    prng_seed(&g_ship_prng, base_seed ^ 0x9E3779B9);
    prng_seed(&g_boss_prng, base_seed ^ 0x6A09E667);
    prng_seed(&g_projectile_prng, base_seed ^ 0xBB67AE85);
    prng_seed(&g_effects_prng, base_seed ^ 0x3C6EF372);
}
