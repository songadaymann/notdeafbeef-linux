
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include "include/visual_types.h"

// External ASM visual functions we can use
extern uint32_t circle_color_asm(float hue, float saturation, float value);
extern void draw_circle_filled_asm(uint32_t *pixels, int cx, int cy, int radius, uint32_t color);
extern void draw_ascii_string_asm(uint32_t *pixels, int x, int y, const char *text, uint32_t color, int bg_alpha);

// Centerpiece implementation using ASM functions
void draw_centerpiece(uint32_t *pixels, centerpiece_t *centerpiece, float time, float level, int frame) {
    // Central orbiting elements driven by audio
    int num_orbs = 6;
    float base_radius = 100.0f + level * 50.0f;
    
    for (int i = 0; i < num_orbs; i++) {
        float angle = time * 0.5f + i * 2.0f * M_PI / num_orbs;
        float radius = base_radius + 30.0f * sin(time * 0.7f + i);
        
        int cx = 800 / 2 + (int)(radius * cos(angle));  // VIS_WIDTH
        int cy = 600 / 2 + (int)(radius * sin(angle));  // VIS_HEIGHT
        int orb_radius = 8 + (int)(level * 15);
        
        float hue = fmod(centerpiece->base_hue + i * 0.15f + level * 0.1f, 1.0f);
        uint32_t color = circle_color_asm(hue, 0.9f, 0.8f + level * 0.2f);
        
        draw_circle_filled_asm(pixels, cx, cy, orb_radius, color);
    }
    
    // Add some text overlay
    char info[64];
    snprintf(info, sizeof(info), "BPM: %d | Mode: %d | Level: %.1f%%", 
             centerpiece->bpm, centerpiece->mode, level * 100.0f);
    
    draw_ascii_string_asm(pixels, 10, 560, info, 0xFFCCCCCC, 128);
}

void init_centerpiece(centerpiece_t *centerpiece, uint32_t seed, int bpm) {
    centerpiece->mode = VIS_MODE_RINGS; // Default mode
    centerpiece->bpm = bpm;
    centerpiece->orbit_radius = 100.0f;
    centerpiece->base_hue = 0.0f;
    centerpiece->orbit_speed = 0.5f;
    
    // Vary based on seed
    srand(seed);
    centerpiece->base_hue = (rand() % 100) / 100.0f;
    centerpiece->orbit_speed = 0.3f + (rand() % 50) / 100.0f;
}

void init_degradation_effects(degradation_t *effects, uint32_t seed) {
    // Simple degradation effects based on seed
    srand(seed);
    effects->persistence = 0.8f + (rand() % 20) / 100.0f;
    effects->scanline_alpha = 50 + (rand() % 100);
    effects->chroma_shift = rand() % 5;
    effects->noise_pixels = rand() % 1000;
    effects->jitter_amount = (rand() % 10) / 100.0f;
    effects->frame_drop_chance = 0.01f;
    effects->color_bleed = 0.1f + (rand() % 20) / 100.0f;
}

// 🔥 CHAOS MODE STUB - Temporary fallback
void draw_bass_hits_asm(uint32_t *pixels, int frame) {
    printf("CHAOS: Bass hits rendering at frame %d\n", frame);
}
