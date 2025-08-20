
// Particles System C Wrapper
// Provides memory allocation for particles ASM code

#include <stdint.h>
#include <string.h>
#include "include/visual_types.h"

// Global particle array - allocated in C, used by ASM
// 256 particles, 32 bytes each (matches ASM struct layout)
static uint8_t particle_data[256 * 32];

// Export this symbol for ASM code to reference
uint8_t *particles_array = particle_data;

// ASM function prototypes
extern void init_particles_asm(void);
extern int is_saw_step_asm(int step);
extern void spawn_explosion_asm(int count, float x, float y, float base_hue, uint32_t seed);
extern void update_particles_asm(float elapsed_ms, float step_sec, float base_hue);
extern void draw_particles_asm(uint32_t *pixels);
extern void reset_particle_step_tracking_asm(void);

// C wrapper functions that call ASM implementations
void init_particles(void) {
    // Clear the particle array first
    memset(particle_data, 0, sizeof(particle_data));
    
    // Call ASM initialization
    init_particles_asm();
}

bool is_saw_step(int step) {
    return is_saw_step_asm(step) != 0;
}

void spawn_explosion(int count, float x, float y, float base_hue, uint32_t seed) {
    spawn_explosion_asm(count, x, y, base_hue, seed);
}

void update_particles(float elapsed_ms, float step_sec, float base_hue) {
    update_particles_asm(elapsed_ms, step_sec, base_hue);
}

void draw_particles(uint32_t *pixels) {
    draw_particles_asm(pixels);
}

void reset_particle_step_tracking(void) {
    reset_particle_step_tracking_asm();
}
