#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <string.h>
#include <ctype.h>
#include "src/include/visual_types.h"
#include "src/include/deterministic_prng.h"

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

// Forward declarations for ASM visual functions
extern void clear_frame_asm(uint32_t *pixels, uint32_t color);
extern void init_terrain_asm(uint32_t seed, float base_hue);
extern void draw_terrain_asm(uint32_t *pixels, int frame);
extern void draw_terrain_enhanced_asm(uint32_t *pixels, int frame, float audio_level);
// Particles removed for now
// extern void init_particles_asm(void);
// extern void update_particles_asm(float elapsed_ms, float step_sec, float base_hue);
// extern void draw_particles_asm(uint32_t *pixels);
extern void init_glitch_system_asm(uint32_t seed, float intensity);
extern void update_glitch_intensity_asm(float new_intensity);
extern void init_bass_hits_asm(void);
extern void draw_bass_hits_asm(uint32_t *pixels, int frame);
extern void update_bass_hits_asm(float elapsed_ms);
extern uint32_t circle_color_asm(float hue, float saturation, float value);
extern void draw_circle_filled_asm(uint32_t *pixels, int cx, int cy, int radius, uint32_t color);
extern void draw_ascii_char_asm(uint32_t *pixels, int x, int y, char c, uint32_t color, int bg_alpha);

// Global pixels buffer for shape drawing
static uint32_t *g_current_pixels = NULL;
void set_current_pixels(uint32_t *pixels) { g_current_pixels = pixels; }

// Workload budget system for 60 FPS stability
typedef struct {
    int max_projectiles;      // Dynamic cap on active projectiles
    int max_boss_shapes;      // Dynamic cap on boss formation complexity
    int min_firing_cooldown;  // Dynamic minimum between shots
    float complexity_factor;  // 0.0-1.0 based on audio intensity
} workload_budget_t;

static workload_budget_t g_budget = {0};

// Workload budget management
void update_workload_budget(float audio_level) {
    // AGGRESSIVE budget to maintain 60 FPS - performance over visual complexity
    
    // Drastically reduced base budgets for 60 FPS stability
    int base_projectiles = 2;  // Reduced from 8
    int base_boss_shapes = 2;  // Reduced from 5  
    int base_cooldown = 10;    // Reduced from 15
    
    // Audio intensity factor (0.0 = quiet, 1.0 = loud)
    g_budget.complexity_factor = audio_level;
    
    // Scale projectiles: 2-6 based on audio, capped at 6 for performance
    g_budget.max_projectiles = base_projectiles + (int)(audio_level * 4);
    if (g_budget.max_projectiles > 6) g_budget.max_projectiles = 6;
    
    // Scale boss complexity: 2-4 shapes max, very conservative
    g_budget.max_boss_shapes = base_boss_shapes + (int)(audio_level * 2);
    if (g_budget.max_boss_shapes > 4) g_budget.max_boss_shapes = 4;
    
    // Faster firing on loud sections, but not too fast
    g_budget.min_firing_cooldown = base_cooldown - (int)(audio_level * 6);
    if (g_budget.min_firing_cooldown < 5) g_budget.min_firing_cooldown = 5;
}

// Projectile system for ship firing
typedef struct {
    float x, y;           // Position
    float vx, vy;         // Velocity
    char character;       // ASCII character ('o', 'x', '-', '0', etc.)
    uint32_t color;       // Projectile color
    int life;             // Remaining life frames
    bool active;          // Is this projectile active?
} projectile_t;

#define MAX_PROJECTILES 32
#define VIS_WIDTH 800
#define VIS_HEIGHT 600
static projectile_t projectiles[MAX_PROJECTILES] = {0};
static int last_shot_frame = -100; // Frame when last shot was fired

// Enhanced boss shape system using all 5 ASM shapes with diversity
extern void draw_ascii_triangle_asm(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame);
extern void draw_ascii_diamond_asm(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame);
extern void draw_ascii_hexagon_asm(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame);
extern void draw_ascii_star_asm(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame);
extern void draw_ascii_square_asm(uint32_t *pixels, int cx, int cy, int size, float rotation, uint32_t color, int alpha, int frame);

void draw_boss_shape(float cx, float cy, int shape_type, int size, float rotation, float hue, float saturation, float value, int frame) {
    if (!g_current_pixels) return; // Safety check
    
    uint32_t color = circle_color_asm(hue, saturation, value);
    int alpha = 255; // Full opacity for boss shapes
    
    // Use all 5 ASM shapes with proper parameters
    switch(shape_type) {
        case 0: // Triangle
            draw_ascii_triangle_asm(g_current_pixels, (int)cx, (int)cy, size, rotation, color, alpha, frame);
            break;
        case 1: // Diamond  
            draw_ascii_diamond_asm(g_current_pixels, (int)cx, (int)cy, size, rotation, color, alpha, frame);
            break;
        case 2: // Hexagon
            draw_ascii_hexagon_asm(g_current_pixels, (int)cx, (int)cy, size, rotation, color, alpha, frame);
            break;
        case 3: // Star
            draw_ascii_star_asm(g_current_pixels, (int)cx, (int)cy, size, rotation, color, alpha, frame);
            break;
        case 4: // Square
            draw_ascii_square_asm(g_current_pixels, (int)cx, (int)cy, size, rotation, color, alpha, frame);
            break;
    }
}

// Projectile system functions
void spawn_projectile(float ship_x, float ship_y, float boss_x, float boss_y, uint32_t seed) {
    // Count active projectiles first
    int active_count = 0;
    for (int i = 0; i < MAX_PROJECTILES; i++) {
        if (projectiles[i].active) active_count++;
    }
    
    // Respect workload budget - don't spawn if at cap
    if (active_count >= g_budget.max_projectiles) {
        return; // Budget exceeded, skip this projectile
    }
    
    // Find an inactive projectile slot
    for (int i = 0; i < MAX_PROJECTILES; i++) {
        if (!projectiles[i].active) {
            // Seed-based projectile type selection
            prng_seed(&g_projectile_prng, seed + i);
            char projectile_chars[] = {'o', 'x', '-', '0', '*', '+', '>', '=', '~'};
            int char_count = sizeof(projectile_chars) / sizeof(projectile_chars[0]);
            
            projectiles[i].x = ship_x + 20; // Start slightly ahead of ship
            projectiles[i].y = ship_y;
            
            // Calculate velocity towards boss
            float dx = boss_x - ship_x;
            float dy = boss_y - ship_y;
            float distance = sqrt(dx*dx + dy*dy);
            float speed = 8.0f; // Pixels per frame
            
            projectiles[i].vx = (dx / distance) * speed;
            projectiles[i].vy = (dy / distance) * speed;
            projectiles[i].character = projectile_chars[prng_range(&g_projectile_prng, char_count)];
            projectiles[i].color = circle_color_asm(0.1f + prng_range(&g_projectile_prng, 100) / 1000.0f, 1.0f, 1.0f); // Yellowish
            projectiles[i].life = 120; // 2 seconds at 60fps
            projectiles[i].active = true;
            break;
        }
    }
}

void update_projectiles(void) {
    for (int i = 0; i < MAX_PROJECTILES; i++) {
        if (projectiles[i].active) {
            // Move projectile
            projectiles[i].x += projectiles[i].vx;
            projectiles[i].y += projectiles[i].vy;
            projectiles[i].life--;
            
            // Deactivate if off screen or life expired
            if (projectiles[i].x < 0 || projectiles[i].x >= VIS_WIDTH ||
                projectiles[i].y < 0 || projectiles[i].y >= VIS_HEIGHT ||
                projectiles[i].life <= 0) {
                projectiles[i].active = false;
            }
        }
    }
}

void draw_projectiles(void) {
    if (!g_current_pixels) return;
    
    for (int i = 0; i < MAX_PROJECTILES; i++) {
        if (projectiles[i].active) {
            draw_ascii_char_asm(g_current_pixels, 
                (int)projectiles[i].x, (int)projectiles[i].y,
                projectiles[i].character, projectiles[i].color, 255);
        }
    }
}

// Sidecar timeline reader (preferred) and audio-analysis fallback
#include "src/include/timeline.h"
void init_audio_visual_mapping(void);
float get_smoothed_audio_level(int frame);
void update_audio_visual_effects(int frame, float base_hue);
float get_audio_driven_glitch_intensity(int frame);
float get_audio_driven_hue_shift(int frame);

// Audio functions
bool load_wav_file(const char *filename);
float get_audio_rms_for_frame(int frame);
float get_audio_bpm(void);
float get_max_rms(void);
float get_audio_duration(void); // Get actual audio duration in seconds
bool is_audio_finished(int frame);
void print_audio_info(void);
void cleanup_audio_data(void);

#define FRAME_TIME_MS (1000 / VIS_FPS)

// PPM image output helpers
static inline void write_frame_ppm(FILE *out, uint32_t *pixels) {
    // Each frame carries its own header (PPM P6) for ffmpeg image2pipe
    fprintf(out, "P6\n%d %d\n255\n", VIS_WIDTH, VIS_HEIGHT);
    for (int y = 0; y < VIS_HEIGHT; y++) {
        for (int x = 0; x < VIS_WIDTH; x++) {
            uint32_t pixel = pixels[y * VIS_WIDTH + x];
            uint8_t r = (pixel >> 16) & 0xFF;
            uint8_t g = (pixel >> 8) & 0xFF;
            uint8_t b = pixel & 0xFF;
            fwrite(&r, 1, 1, out);
            fwrite(&g, 1, 1, out);
            fwrite(&b, 1, 1, out);
        }
    }
    fflush(out);
}

void save_frame_as_ppm(uint32_t *pixels, int frame_num) {
    char filename[256];
    snprintf(filename, sizeof(filename), "frame_%04d.ppm", frame_num);
    FILE *f = fopen(filename, "wb");
    if (!f) { fprintf(stderr, "Could not create %s\n", filename); return; }
    write_frame_ppm(f, pixels);
    fclose(f);
    fprintf(stderr, "✅ Generated frame_%04d.ppm\n", frame_num);
}

// Custom top terrain drawing function
void draw_top_terrain(uint32_t *pixels, int frame, float hue, float audio_level) {
    // Simple procedural top terrain using different algorithm
    const int char_width = 8; // Use proper 8x12 glyph spacing
    const int char_height = 12;
    const char terrain_chars[] = "^^^^====~~~~----____";
    const int num_chars = 20;
    const int char_alpha = 255; // Fully opaque - this was the bug!
    
    // Create brighter color based on hue
    uint32_t color = circle_color_asm(hue, 1.0f, 1.0f); // Full brightness and saturation
    
    // Generate terrain from top down - make it much more visible
    for (int x = 0; x < VIS_WIDTH; x += char_width) {
        // Use different pattern than bottom terrain
        int pattern = (x / char_width + frame / 2) % num_chars;
        char c = terrain_chars[pattern];
        
        // Audio-reactive height - different response than bottom
        int height_variation = (int)(audio_level * 8) + 3; // Audio variation
        int y_offset = (int)(sin((x + frame * 3) * 0.03f) * height_variation);
        
        // Draw multiple rows for thickness, from top down
        for (int row = 0; row < 6 + height_variation; row++) {
            int y = row * char_height + y_offset + 10; // Start 10 pixels from top
            if (y >= 0 && y < VIS_HEIGHT / 2) { // Use top half
                draw_ascii_char_asm(pixels, x, y, c, color, char_alpha);
            }
        }
    }
}

// Ship component system - seed determines design
typedef struct {
    const char* nose_patterns[4];     // 4 different nose designs
    const char* body_patterns[4];     // 4 different body designs  
    const char* wing_patterns[4];     // 4 different wing designs
    const char* trail_patterns[4];    // 4 different trail designs
    int sizes[3];                     // 3 different sizes
} ship_components_t;

ship_components_t ship_parts = {
    .nose_patterns = {
        "  ^  ",  // Classic
        " /^\\ ", // Wide
        " <*> ", // Star
        " >+< "  // Cross
    },
    .body_patterns = {
        "[###]", // Block
        "<ooo>", // Circles  
        "{***}", // Stars
        "(===)" // Lines
    },
    .wing_patterns = {
        "<   >", // Simple
        "<<+>>", // Double
        "[---]", // Brackets
        "\\___/" // Curves
    },
    .trail_patterns = {
        " ~~~ ", // Waves
        " --- ", // Lines
        " *** ", // Stars
        " ... "  // Dots
    },
    .sizes = {1, 2, 3} // Size multipliers
};

// Ship flying through the terrain corridor
void draw_ship(uint32_t *pixels, int frame, float hue, float audio_level, uint32_t seed) {
    // Ship position on LEFT side of screen (leaving room for enemies)
    float base_x = VIS_WIDTH * 0.15f; // 15% from left (moved further left)
    float center_y = VIS_HEIGHT / 2.0f;
    
    // Audio-reactive movement - enhanced for bigger ship
    float sway = sin(frame * 0.05f) * 40.0f; // Side-to-side movement  
    float bob = sin(frame * 0.08f) * 30.0f;  // Up-down movement
    float audio_dodge = audio_level * 35.0f; // React to audio
    
    // Calculate final position
    int ship_x = (int)(base_x + sway + audio_dodge);
    int ship_y = (int)(center_y + bob);
    
    // Calculate boss position for targeting (using same logic as draw_enemy_boss)
    float boss_base_x = VIS_WIDTH * 0.75f;
    float boss_center_y = VIS_HEIGHT / 2.0f;
    float boss_hover = sin(frame * 0.03f) * 20.0f;
    float boss_pulse = sin(frame * 0.12f) * 15.0f;
    float boss_audio_react = audio_level * 25.0f;
    int boss_x = (int)(boss_base_x + boss_hover - boss_audio_react);
    int boss_y = (int)(boss_center_y + boss_pulse);
    
    // Ship firing logic - budget-aware firing rate
    if (frame - last_shot_frame >= g_budget.min_firing_cooldown) {
        spawn_projectile(ship_x, ship_y, boss_x, boss_y, seed + frame);
        last_shot_frame = frame;
    }
    
    // Seed-based ship design selection
    prng_seed(&g_ship_prng, seed);
    int nose_type = prng_range(&g_ship_prng, 4);
    int body_type = prng_range(&g_ship_prng, 4);
    int wing_type = prng_range(&g_ship_prng, 4); 
    int trail_type = prng_range(&g_ship_prng, 4);
    int size = ship_parts.sizes[prng_range(&g_ship_prng, 3)];
    
    // Seed-based colors - create unique palette
    float primary_hue = prng_float(&g_ship_prng);
    float secondary_hue = primary_hue + 0.3f;
    if (secondary_hue > 1.0f) secondary_hue -= 1.0f;
    
    uint32_t primary_color = circle_color_asm(primary_hue, 1.0f, 1.0f);
    uint32_t secondary_color = circle_color_asm(secondary_hue, 0.8f, 0.9f);
    
    // Selected ship components
    const char* nose = ship_parts.nose_patterns[nose_type];
    const char* body = ship_parts.body_patterns[body_type];
    const char* wings = ship_parts.wing_patterns[wing_type];
    const char* trail = ship_parts.trail_patterns[trail_type];
    
    int char_spacing = 8 * size;
    int line_spacing = 12 * size;
    
    // Draw ship layers (bigger and more detailed)
    for (int layer = 0; layer < size; layer++) {
        int offset_y = layer * 2; // Slight layer offset
        
        // Nose (top)
        for (int i = 0; i < 5; i++) {
            if (nose[i] != ' ') {
                for (int s = 0; s < size; s++) {
                    draw_ascii_char_asm(pixels, 
                        ship_x + (i-2)*char_spacing + s*4, 
                        ship_y - line_spacing*2 + offset_y, 
                        nose[i], primary_color, 255);
                }
            }
        }
        
        // Wings (upper middle)
        for (int i = 0; i < 5; i++) {
            if (wings[i] != ' ') {
                for (int s = 0; s < size; s++) {
                    draw_ascii_char_asm(pixels, 
                        ship_x + (i-2)*char_spacing + s*4, 
                        ship_y - line_spacing + offset_y, 
                        wings[i], secondary_color, 255);
                }
            }
        }
        
        // Body (center) 
        for (int i = 0; i < 5; i++) {
            if (body[i] != ' ') {
                for (int s = 0; s < size; s++) {
                    draw_ascii_char_asm(pixels, 
                        ship_x + (i-2)*char_spacing + s*4, 
                        ship_y + offset_y, 
                        body[i], primary_color, 255);
                }
            }
        }
        
        // Trail (bottom)
        for (int i = 0; i < 5; i++) {
            if (trail[i] != ' ') {
                for (int s = 0; s < size; s++) {
                    draw_ascii_char_asm(pixels, 
                        ship_x + (i-2)*char_spacing + s*4, 
                        ship_y + line_spacing + offset_y, 
                        trail[i], secondary_color, 255);
                }
            }
        }
    }
}

// Enhanced boss system with massive diversity - mix and match shapes, sizes, colors
void draw_enemy_boss(uint32_t *pixels, int frame, float hue, float audio_level, uint32_t seed) {
    // Boss position on RIGHT side of screen (75% from left)
    float base_x = VIS_WIDTH * 0.75f; // 75% from left
    float center_y = VIS_HEIGHT / 2.0f;
    
    // Audio-reactive movement - different pattern from ship
    float hover = sin(frame * 0.03f) * 20.0f; // Slower hovering movement
    float pulse = sin(frame * 0.12f) * 15.0f; // Pulsing motion
    float audio_react = audio_level * 25.0f; // React to audio differently
    
    // Calculate final position
    int boss_x = (int)(base_x + hover - audio_react); // Move left on audio hits
    int boss_y = (int)(center_y + pulse);
    
    // Seed-based boss design with MASSIVE DIVERSITY
    prng_seed(&g_boss_prng, seed + 0x1000); // Different seed offset for boss variety
    
    // 1. Random formation type (8 different formation patterns)
    int formation_type = prng_range(&g_boss_prng, 8);
    
    // 2. Budget-aware number of components (respects workload cap)
    int max_shapes = (g_budget.max_boss_shapes > 3) ? g_budget.max_boss_shapes : 3;
    int num_components = 3 + prng_range(&g_boss_prng, max_shapes - 2);
    
    // 3. Base boss hue with variety
    float boss_base_hue = hue + prng_float(&g_boss_prng); // More hue variety
    if (boss_base_hue > 1.0f) boss_base_hue -= 1.0f;
    
    // 4. Size variety (small to massive)
    int base_size = 15 + prng_range(&g_boss_prng, 25); // Size range: 15-40
    
    // 5. Rotation variety
    float base_rotation = prng_range(&g_boss_prng, 360) * M_PI / 180.0f;
    
    // Draw diverse boss formations
    switch(formation_type) {
        case 0: // Star Burst Formation - mixed shapes radiating outward
            for (int i = 0; i < num_components; i++) {
                float angle = (2.0f * M_PI * i) / num_components;
                float radius = 30 + (i * 15); // Expanding radius
                int shape = prng_range(&g_boss_prng, 5); // All 5 shapes
                int size = base_size + prng_range(&g_boss_prng, 15) - 7; // Size variety ±7
                float shape_hue = boss_base_hue + (i * 0.1f); 
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                float sat = 0.7f + prng_range(&g_boss_prng, 30) / 100.0f; // Saturation variety
                float val = 0.8f + prng_range(&g_boss_prng, 20) / 100.0f; // Brightness variety
                float rotation = base_rotation + (i * 0.3f);
                
                int x = boss_x + (int)(cos(angle) * radius);
                int y = boss_y + (int)(sin(angle) * radius);
                draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
            
        case 1: // Cluster Formation - tight group with mixed shapes
            for (int i = 0; i < num_components; i++) {
                int shape = prng_range(&g_boss_prng, 5);
                int size = base_size + prng_range(&g_boss_prng, 10) - 5;
                float cluster_radius = 20 + prng_range(&g_boss_prng, 30);
                float angle = prng_range(&g_boss_prng, 360) * M_PI / 180.0f;
                float shape_hue = boss_base_hue + prng_range(&g_boss_prng, 30) / 100.0f;
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                float sat = 0.6f + prng_range(&g_boss_prng, 40) / 100.0f;
                float val = 0.7f + prng_range(&g_boss_prng, 30) / 100.0f;
                float rotation = base_rotation + prng_range(&g_boss_prng, 360) * M_PI / 180.0f;
                
                int x = boss_x + (int)(cos(angle) * cluster_radius);
                int y = boss_y + (int)(sin(angle) * cluster_radius);
                draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
            
        case 2: // Wing Formation - symmetrical left/right
            int wing_shapes = num_components / 2;
            for (int i = 0; i < wing_shapes; i++) {
                int shape = prng_range(&g_boss_prng, 5);
                int size = base_size + prng_range(&g_boss_prng, 12) - 6;
                float wing_distance = 40 + (i * 20);
                float y_offset = (i - wing_shapes/2) * 25;
                float shape_hue = boss_base_hue + (i * 0.15f);
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                float sat = 0.8f + prng_range(&g_boss_prng, 20) / 100.0f;
                float val = 0.9f + prng_range(&g_boss_prng, 10) / 100.0f;
                float rotation = base_rotation + (i * 0.2f);
                
                // Left wing
                draw_boss_shape(boss_x - wing_distance, boss_y + y_offset, shape, size, rotation, shape_hue, sat, val, frame);
                // Right wing (different shape)
                int right_shape = (shape + 1 + prng_range(&g_boss_prng, 4)) % 5;
                draw_boss_shape(boss_x + wing_distance, boss_y + y_offset, right_shape, size, -rotation, shape_hue + 0.1f, sat, val, frame);
            }
            break;
            
        case 3: // Spiral Formation - shapes in rotating spiral
            for (int i = 0; i < num_components; i++) {
                float spiral_angle = (i * 0.6f) + (frame * 0.02f); // Rotating spiral
                float spiral_radius = 10 + (i * 8);
                int shape = (i + seed) % 5; // Sequential shapes
                int size = base_size + (i % 8) - 4;
                float shape_hue = boss_base_hue + (i * 0.08f);
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                float sat = 0.7f + ((i * 13) % 30) / 100.0f;
                float val = 0.8f + ((i * 17) % 20) / 100.0f;
                float rotation = spiral_angle + base_rotation;
                
                int x = boss_x + (int)(cos(spiral_angle) * spiral_radius);
                int y = boss_y + (int)(sin(spiral_angle) * spiral_radius);
                draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
            
        case 4: // Grid Formation - organized rectangular pattern
            int grid_size = (int)sqrt(num_components);
            for (int i = 0; i < num_components; i++) {
                int grid_x = i % grid_size;
                int grid_y = i / grid_size;
                int shape = (grid_x + grid_y + seed) % 5; // Pattern-based shapes
                int size = base_size + ((grid_x + grid_y) % 6) - 3;
                float shape_hue = boss_base_hue + ((grid_x + grid_y) * 0.12f);
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                float sat = 0.6f + ((grid_x * 7 + grid_y * 11) % 40) / 100.0f;
                float val = 0.7f + ((grid_x * 5 + grid_y * 13) % 30) / 100.0f;
                float rotation = base_rotation + (grid_x + grid_y) * 0.25f;
                
                int x = boss_x + (grid_x - grid_size/2) * 30;
                int y = boss_y + (grid_y - grid_size/2) * 30;
                draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
            
        case 5: // Random Chaos Formation - completely random placement
            for (int i = 0; i < num_components; i++) {
                int shape = prng_range(&g_boss_prng, 5);
                int size = 10 + prng_range(&g_boss_prng, 30); // Wide size range
                float random_x = boss_x + prng_range(&g_boss_prng, 120) - 60; // ±60 pixel spread
                float random_y = boss_y + prng_range(&g_boss_prng, 120) - 60;
                float shape_hue = prng_range(&g_boss_prng, 100) / 100.0f; // Completely random hue
                float sat = 0.5f + prng_range(&g_boss_prng, 50) / 100.0f;
                float val = 0.6f + prng_range(&g_boss_prng, 40) / 100.0f;
                float rotation = prng_range(&g_boss_prng, 360) * M_PI / 180.0f;
                
                draw_boss_shape(random_x, random_y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
            
        case 6: // Layered Formation - concentric circles of different shapes
            int layers = 1 + (num_components / 4);
            for (int layer = 0; layer < layers; layer++) {
                int shapes_in_layer = 3 + layer * 2;
                float layer_radius = 20 + layer * 25;
                for (int i = 0; i < shapes_in_layer && layer * shapes_in_layer + i < num_components; i++) {
                    float angle = (2.0f * M_PI * i) / shapes_in_layer;
                    int shape = (layer + i) % 5;
                    int size = base_size - layer * 3; // Smaller shapes in outer layers
                    float shape_hue = boss_base_hue + layer * 0.2f + i * 0.1f;
                    if (shape_hue > 1.0f) shape_hue -= 1.0f;
                    float sat = 0.8f - layer * 0.1f;
                    float val = 0.9f - layer * 0.1f;
                    float rotation = base_rotation + layer * 0.5f + i * 0.3f;
                    
                    int x = boss_x + (int)(cos(angle) * layer_radius);
                    int y = boss_y + (int)(sin(angle) * layer_radius);
                    draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
                }
            }
            break;
            
        case 7: // Pulsing Formation - sizes vary with audio and frame
            for (int i = 0; i < num_components; i++) {
                float pulse_phase = (i * 0.5f) + (frame * 0.08f);
                float pulse_factor = 0.7f + 0.3f * sin(pulse_phase) + audio_level * 0.4f;
                int shape = i % 5;
                int size = (int)(base_size * pulse_factor);
                float angle = (2.0f * M_PI * i) / num_components;
                float radius = 35 + sin(frame * 0.05f + i) * 15; // Varying radius
                float shape_hue = boss_base_hue + sin(pulse_phase) * 0.2f;
                if (shape_hue > 1.0f) shape_hue -= 1.0f;
                if (shape_hue < 0.0f) shape_hue += 1.0f;
                float sat = 0.7f + audio_level * 0.3f;
                float val = 0.8f + sin(pulse_phase) * 0.2f;
                float rotation = base_rotation + pulse_phase;
                
                int x = boss_x + (int)(cos(angle) * radius);
                int y = boss_y + (int)(sin(angle) * radius);
                draw_boss_shape(x, y, shape, size, rotation, shape_hue, sat, val, frame);
            }
            break;
    }
}

int main(int argc, char *argv[]) {
    // CLI: <audio.wav> [seed_hex] [max_frames] [--pipe-ppm] [--range start end]
    bool pipe_ppm = false;
    int range_start = -1, range_end = -1;
    
    if (argc < 2 || argc > 8) {
        printf("🎬 NotDeafBeef Frame Generator\n");
        printf("Usage: %s <audio_file.wav> [seed_hex] [max_frames] [--pipe-ppm] [--range start end]\n", argv[0]);
        printf("Example: %s audio.wav 0xDEADBEEF\n", argv[0]);
        printf("Example: %s audio.wav 0xDEADBEEF 24 --pipe-ppm  # Stream frames to stdout\n", argv[0]);
        printf("Example: %s audio.wav 0xDEADBEEF 0 --range 100 200  # Render frames 100-199\n", argv[0]);
        return 1;
    }
    
    // Parse flags and options
    int arg_idx = argc - 1;
    while (arg_idx >= 2) {
        if (strcmp(argv[arg_idx], "--pipe-ppm") == 0) {
            pipe_ppm = true;
            argc--;
            arg_idx--;
        } else if (strcmp(argv[arg_idx], "--range") == 0 && arg_idx >= 3) {
            // --range start end
            range_end = atoi(argv[arg_idx + 1]);
            range_start = atoi(argv[arg_idx]);
            argc -= 3; // Remove --range start end
            arg_idx -= 3;
        } else {
            break;
        }
    }

    printf("🎨 Generating visual frames from audio: %s\n", argv[1]);
    
    // Load audio file
    if (!load_wav_file(argv[1])) {
        fprintf(stderr, "❌ Failed to load audio file: %s\n", argv[1]);
        return 1;
    }
    
    print_audio_info();
    
    // Initialize audio-visual mapping
    init_audio_visual_mapping();
    
    // Initialize visual systems with seed from audio
    uint32_t seed = 0xCAFEBABE; // Could be derived from audio file hash  
    
    // For testing: allow command line seed override
    if (argc >= 3) {
        // OPTIMIZATION: Hash long transaction hashes to 32-bit seeds
        seed = hash_transaction_to_seed(argv[2]);
        printf("🎲 Using hashed seed: 0x%08X (from %s)\n", seed, argv[2]);
    }
    
    // Initialize PRNG streams
    init_visual_prng_streams(seed);
    
    // Allocate pixel buffer
    uint32_t *pixels = calloc(VIS_WIDTH * VIS_HEIGHT, sizeof(uint32_t));
    if (!pixels) {
        fprintf(stderr, "❌ Failed to allocate pixel buffer\n");
        return 1;
    }
    
    printf("🚀 Initializing visual systems...\n");
    
    float base_hue = 0.5f;

    // Prefer timeline sidecar if present (<audio>.json) to drive visuals deterministically
    timeline_t tl = {0};
    char sidecar_path[512];
    snprintf(sidecar_path, sizeof(sidecar_path), "%s.json", argv[1]);
    bool have_timeline = timeline_load(sidecar_path, &tl);
    if (have_timeline) {
        printf("🧭 Using timeline sidecar: %s\n", sidecar_path);
    } else {
        printf("ℹ️  No timeline sidecar found (%s). Falling back to WAV analysis.\n", sidecar_path);
    }
    
    init_terrain_asm(seed, base_hue);
    // init_particles_asm(); // Removed for now
    init_glitch_system_asm(seed, 0.5f);
    init_bass_hits_asm();
    
    // Initialize second terrain system for top with different color
    uint32_t top_seed = seed ^ 0x12345678; // Different seed for variation
    float top_hue = base_hue + 0.3f; // Shift hue for different color
    if (top_hue > 1.0f) top_hue -= 1.0f; // Wrap around
    // We'll call init_terrain_asm again but we need a way to have two terrains
    
    printf("🎬 Generating frames at 60 FPS...\n");
    
    int frame = 0;
    int total_frames = 0;
    
    // Calculate total frames needed (audio duration * FPS)
    // Get actual audio duration from loaded WAV file instead of hardcoded 5.0s
    float audio_duration = get_audio_duration(); // Use actual audio duration
    total_frames = (int)(audio_duration * VIS_FPS);
    
    // Allow frame limit override for quick testing
    if (argc == 4) {
        int max_frames = atoi(argv[3]);
        if (max_frames > 0 && max_frames < total_frames) {
            total_frames = max_frames;
            fprintf(pipe_ppm ? stderr : stdout, "🎯 Limiting to %d frames for quick test\n", total_frames);
        }
    }
    
    // Apply range filtering if specified
    int start_frame = 0;
    int end_frame = total_frames;
    if (range_start >= 0 && range_end >= 0) {
        if (range_start >= total_frames || range_end <= range_start) {
            fprintf(stderr, "❌ Invalid range: %d-%d (total frames: %d)\n", range_start, range_end, total_frames);
            return 1;
        }
        start_frame = range_start;
        end_frame = (range_end > total_frames) ? total_frames : range_end;
        fprintf(pipe_ppm ? stderr : stdout, "🎯 Rendering slice: frames %d-%d\n", start_frame, end_frame-1);
    }
    
    fprintf(pipe_ppm ? stderr : stdout,
            "📽️  Total frames to generate: %d (%.1f seconds at %d FPS)\n",
            end_frame - start_frame, audio_duration, VIS_FPS);
    
    frame = start_frame; // Start from specified frame
    while (frame < end_frame && !is_audio_finished(frame)) {
        // Clear frame
        clear_frame_asm(pixels, 0x000000); // Black background
        
        // Set current pixels for shape drawing functions
        set_current_pixels(pixels);
        
        // Get audio-driven parameters (from sidecar if available)
        float audio_hue = have_timeline ? timeline_compute_hue(&tl, frame, VIS_FPS)
                                        : get_audio_driven_hue_shift(frame);
        float audio_level = have_timeline ? timeline_compute_level(&tl, frame, VIS_FPS)
                                          : get_smoothed_audio_level(frame);
        float glitch_intensity = have_timeline ? timeline_compute_glitch(&tl, frame, VIS_FPS)
                                               : get_audio_driven_glitch_intensity(frame);
        
        // Update workload budget based on current audio intensity
        update_workload_budget(audio_level);
        
        // Update audio-visual effects
        update_audio_visual_effects(frame, audio_hue);
        
        // Update glitch intensity
        update_glitch_intensity_asm(glitch_intensity);
        
        // Focus on terrain systems
        
        // Calculate different audio responses for each terrain
        float bottom_speed_multiplier = 1.0f + audio_level * 3.0f; // 1x to 4x speed
        float top_hue = audio_hue + 0.3f; // Different hue for top terrain
        if (top_hue > 1.0f) top_hue -= 1.0f;
        
        // Draw bottom terrain (enhanced system) - moderate speed with dynamic colors
        int bottom_frame = (int)(frame * bottom_speed_multiplier);
        draw_terrain_enhanced_asm(pixels, bottom_frame, audio_level);
        
        // Draw top terrain (new system) - different pattern and color
        draw_top_terrain(pixels, frame, top_hue, audio_level);
        
        // Update bass hits animation (needed for proper rendering)
        float elapsed_ms = frame * FRAME_TIME_MS;
        update_bass_hits_asm(elapsed_ms);
        
        // Budget-aware visual rendering - skip expensive elements on heavy frames
        if (g_budget.complexity_factor < 0.8f) {  // Only render complex elements when audio is not too intense
            // Draw ship flying through the corridor (pass seed for unique design)
            draw_ship(pixels, frame, audio_hue, audio_level, seed);
            
            // Draw enemy boss on the right side
            draw_enemy_boss(pixels, frame, audio_hue, audio_level, seed);
            
            // Update and draw projectiles (ship firing at boss)
            update_projectiles();
            draw_projectiles();
        } else {
            // High intensity - only update projectiles, don't render ship/boss
            update_projectiles();
            draw_projectiles();
        }
        
        // Draw the bass hits (this renders the ship and any other shapes)
        draw_bass_hits_asm(pixels, frame);
        
        // Output frame (with slice-aware naming)
        if (pipe_ppm) {
            write_frame_ppm(stdout, pixels);
        } else {
            // Include range info in filename for parallel slice rendering
            if (range_start >= 0 && range_end >= 0) {
                char filename[256];
                snprintf(filename, sizeof(filename), "frame_%04d_slice_%d_%d.ppm", frame, range_start, range_end-1);
                FILE *f = fopen(filename, "wb");
                if (!f) { fprintf(stderr, "Could not create %s\n", filename); return 1; }
                write_frame_ppm(f, pixels);
                fclose(f);
                fprintf(stderr, "✅ Generated %s\n", filename);
            } else {
                save_frame_as_ppm(pixels, frame);
            }
        }
        
        // Progress indicator
        if (!pipe_ppm && frame % 30 == 0) {
            printf("🎬 Frame %d/%d (%.1f%% complete)\n",
                   frame, end_frame, ((frame - start_frame) * 100.0f) / (end_frame - start_frame));
        } else if (pipe_ppm && frame % 120 == 0) {
            fprintf(stderr, "🎬 Frame %d/%d (%.1f%%)\n",
                    frame, end_frame, ((frame - start_frame) * 100.0f) / (end_frame - start_frame));
        }
        
        frame++;
    }
    
    if (!pipe_ppm) {
        printf("🎉 Frame generation complete! Generated %d frames\n", frame - start_frame);
        if (range_start >= 0 && range_end >= 0) {
            printf("📽️  Slice complete: frames %d-%d\n", range_start, range_end-1);
            printf("📽️  To merge slices: use parallel_render_coordinator.sh\n");
        } else {
            printf("📽️  To create video: ffmpeg -r 60 -i frame_%%04d.ppm -c:v libx264 -pix_fmt yuv420p output.mp4\n");
        }
    } else {
        fprintf(stderr, "🎉 Frame piping complete! Sent %d frames to stdout.\n", frame - start_frame);
        fprintf(stderr, "💡 Example: ./generate_frames audio.wav 0xSEED --pipe-ppm | ffmpeg -r 60 -f image2pipe -vcodec ppm -i - -i audio.wav -c:v libx264 -pix_fmt yuv420p -shortest output.mp4\n");
    }
    
    // Cleanup
    free(pixels);
    cleanup_audio_data();
    if (have_timeline) timeline_free(&tl);
    
    return 0;
}



