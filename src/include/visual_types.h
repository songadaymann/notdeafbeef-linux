
#ifndef VISUAL_TYPES_H
#define VISUAL_TYPES_H

#include <stdint.h>

#define VIS_FPS 60
#define WIDTH 800
#define HEIGHT 600
#define VIS_WIDTH 800
#define VIS_HEIGHT 600

// HSV color structure
typedef struct {
    float h;  // Hue [0, 1]
    float s;  // Saturation [0, 1] 
    float v;  // Value [0, 1]
} hsv_t;

// RGB color structure
typedef struct {
    uint8_t r;  // Red [0, 255]
    uint8_t g;  // Green [0, 255]
    uint8_t b;  // Blue [0, 255]
    uint8_t a;  // Alpha [0, 255]
} color_t;

// Point with float coordinates
typedef struct {
    float x;
    float y;
} pointf_t;

// Visual modes based on BPM
typedef enum {
    VIS_MODE_THICK = 0,
    VIS_MODE_RINGS = 1,
    VIS_MODE_POLY = 2, 
    VIS_MODE_LISSA = 3
} visual_mode_t;

// Degradation effects structure
typedef struct {
    float persistence;
    int scanline_alpha;
    int chroma_shift;
    int noise_pixels;
    float jitter_amount;
    float frame_drop_chance;
    float color_bleed;
} degradation_t;

// Centerpiece structure
typedef struct {
    visual_mode_t mode;
    int bpm;
    float orbit_radius;
    float base_hue;
    float orbit_speed;
} centerpiece_t;

// Visual context structure
typedef struct {
    centerpiece_t centerpiece;
    degradation_t effects;
    uint32_t seed;
    int frame_count;
    float elapsed_time;
    
    // Additional fields for integration
    uint32_t *pixels;      // Frame buffer
    int frame;             // Current frame number
    float time;            // Current time in seconds
    float step_sec;        // Duration of 16th note
    int bpm;               // Beats per minute
} visual_context_t;

#endif // VISUAL_TYPES_H
