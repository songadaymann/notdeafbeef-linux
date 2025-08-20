#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <time.h>
#include <math.h>
#include "include/visual_types.h"

// Forward declarations for ASM visual functions
extern void clear_frame_asm(uint32_t *pixels, uint32_t color);
extern void init_terrain_asm(uint32_t seed, float base_hue);
extern void draw_terrain_asm(uint32_t *pixels, int frame);
extern void init_particles_asm(void);
extern void update_particles_asm(float elapsed_ms, float step_sec, float base_hue);
extern void draw_particles_asm(uint32_t *pixels);
extern void init_glitch_system_asm(uint32_t seed, float intensity);
extern void update_glitch_intensity_asm(float new_intensity);
extern void init_bass_hits_asm(void);
extern void spawn_bass_hit_asm(float cx, float cy, int shape_type, float base_hue);
extern void draw_bass_hits_asm(uint32_t *pixels, int frame);
extern uint32_t circle_color_asm(float hue, float saturation, float value);
extern void draw_circle_filled_asm(uint32_t *pixels, int cx, int cy, int radius, uint32_t color);
extern void draw_ascii_string_asm(uint32_t *pixels, int x, int y, const char *text, uint32_t color, int bg_alpha);

// C functions that remain (system interface)
void draw_centerpiece(uint32_t *pixels, centerpiece_t *centerpiece, float time, float level, int frame);
void init_centerpiece(centerpiece_t *centerpiece, uint32_t seed, int bpm);
void init_degradation_effects(degradation_t *effects, uint32_t seed);
bool load_wav_file(const char *filename);
float get_audio_rms_for_frame(int frame);
float get_audio_bpm(void);
float get_max_rms(void);
bool is_audio_finished(int frame);
void print_audio_info(void);
void cleanup_audio_data(void);
void start_audio_playback(void);
void stop_audio_playback(void);

// Audio-visual mapping functions
void init_audio_visual_mapping(void);
float get_smoothed_audio_level(int frame);
bool detect_beat_onset(int frame);
float get_bass_energy(int frame);
float get_treble_energy(int frame);
void update_audio_visual_effects(int frame, float base_hue);
float get_audio_driven_glitch_intensity(int frame);
float get_audio_driven_hue_shift(int frame);

#define FRAME_TIME_MS (1000 / VIS_FPS)

typedef struct {
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Texture *texture;
    visual_context_t visual;
    bool running;
} VisualContext;

static VisualContext ctx = {0};

static bool init_sdl(void) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return false;
    }

    ctx.window = SDL_CreateWindow(
        "NotDeafBeef Visual",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        VIS_WIDTH, VIS_HEIGHT,
        SDL_WINDOW_SHOWN
    );
    
    if (!ctx.window) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        return false;
    }

    ctx.renderer = SDL_CreateRenderer(ctx.window, -1, SDL_RENDERER_ACCELERATED);
    if (!ctx.renderer) {
        fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        return false;
    }

    ctx.texture = SDL_CreateTexture(
        ctx.renderer,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        VIS_WIDTH, VIS_HEIGHT
    );
    
    if (!ctx.texture) {
        fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
        return false;
    }

    ctx.visual.pixels = calloc(VIS_WIDTH * VIS_HEIGHT, sizeof(uint32_t));
    if (!ctx.visual.pixels) {
        fprintf(stderr, "Failed to allocate pixel buffer\n");
        return false;
    }

    // Load and analyze audio file
    const char *wav_file = "src/c/seed_0xcafebabe.wav";
    if (!load_wav_file(wav_file)) {
        printf("Failed to load audio file: %s\n", wav_file);
        printf("Falling back to test mode\n");
        // Fallback to test parameters
        ctx.visual.bpm = 120;
    } else {
        printf("Successfully loaded audio file!\n");
        print_audio_info();
        ctx.visual.bpm = (int)get_audio_bpm();
    }
    
    // Initialize visual system with real audio parameters
    ctx.visual.seed = 0xcafebabe;  // Match the WAV file seed
    ctx.visual.frame = 0;
    ctx.visual.time = 0.0f;
    ctx.visual.step_sec = 60.0f / ctx.visual.bpm / 4.0f;  // 16th note duration
    
    init_centerpiece(&ctx.visual.centerpiece, ctx.visual.seed, ctx.visual.bpm);
    init_degradation_effects(&ctx.visual.effects, ctx.visual.seed);
    
    // Initialize ASM terrain system
    init_terrain_asm(ctx.visual.seed, ctx.visual.centerpiece.base_hue);
    
    // Initialize ASM particle system
    init_particles_asm();
    
    // Initialize ASM glitch system with medium intensity
    init_glitch_system_asm(ctx.visual.seed, 0.6f);
    
    // Initialize ASM bass hit system
    init_bass_hits_asm();
    
    // Initialize audio-visual mapping
    init_audio_visual_mapping();
    
    // Start audio playback
    start_audio_playback();

    ctx.running = true;
    return true;
}

static void cleanup_sdl(void) {
    stop_audio_playback();
    cleanup_audio_data();
    if (ctx.visual.pixels) free(ctx.visual.pixels);
    if (ctx.texture) SDL_DestroyTexture(ctx.texture);
    if (ctx.renderer) SDL_DestroyRenderer(ctx.renderer);
    if (ctx.window) SDL_DestroyWindow(ctx.window);
    SDL_Quit();
}

static void handle_events(void) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                ctx.running = false;
                break;
            case SDL_KEYDOWN:
                if (event.key.keysym.sym == SDLK_ESCAPE) {
                    ctx.running = false;
                }
                break;
        }
    }
}

static void render_frame(void) {
    // Clear to black using ASM
    clear_frame_asm(ctx.visual.pixels, 0xFF000000);
    
    // Update time and frame
    ctx.visual.time = ctx.visual.frame / (float)VIS_FPS;
    
    // Get enhanced audio analysis
    float audio_level = get_smoothed_audio_level(ctx.visual.frame);
    float bass_energy = get_bass_energy(ctx.visual.frame);
    float treble_energy = get_treble_energy(ctx.visual.frame);
    
    // Update dynamic base hue based on audio
    ctx.visual.centerpiece.base_hue = get_audio_driven_hue_shift(ctx.visual.frame);
    
    // Calculate elapsed time in segment (for particle timing) with looping
    float segment_duration_ms = 9220.0f; // ~9.22 seconds from our audio
    float elapsed_ms = fmod(ctx.visual.time * 1000.0f, segment_duration_ms);
    
    // Update particles using ASM (handles explosions and physics)
    update_particles_asm(elapsed_ms, ctx.visual.step_sec, ctx.visual.centerpiece.base_hue);
    
    // Audio-reactive effects (particle explosions, bass hits)
    update_audio_visual_effects(ctx.visual.frame, ctx.visual.centerpiece.base_hue);
    
    // Update glitch intensity based on audio characteristics
    float glitch_intensity = get_audio_driven_glitch_intensity(ctx.visual.frame);
    update_glitch_intensity_asm(glitch_intensity);
    
    // Draw orbiting centerpiece (C function with some ASM calls)
    draw_centerpiece(ctx.visual.pixels, &ctx.visual.centerpiece, ctx.visual.time, audio_level, ctx.visual.frame);
    
    // 🚀 CHAOS MODE RENDERING - Multiple layers with audio-reactive speed!
    float chaos_level = get_smoothed_audio_level(ctx.visual.frame);
    
    // 🔯 MULTI-LAYER BASS HITS - Draw multiple times for intensity!
    for (int layer = 0; layer < (int)(chaos_level * 3) + 1; layer++) {
        draw_bass_hits_asm(ctx.visual.pixels, ctx.visual.frame + layer * 5);
    }
    
    // 🏔️ HYPER-SPEED TERRAIN - Speed varies with audio!
    int terrain_speed = (int)(1 + chaos_level * 8); // 1x to 9x speed
    draw_terrain_asm(ctx.visual.pixels, ctx.visual.frame * terrain_speed);
    
    // 💥 PARTICLE STORM - Draw multiple times for particle density!
    for (int burst = 0; burst < (int)(chaos_level * 4) + 1; burst++) {
        draw_particles_asm(ctx.visual.pixels);
    }
    
    // TODO: Add other visual elements
    // - Audio-reactive elements
    // - Post-processing effects
    
    // Update texture with pixel buffer
    SDL_UpdateTexture(ctx.texture, NULL, ctx.visual.pixels, VIS_WIDTH * sizeof(uint32_t));
    
    // Render to screen
    SDL_RenderClear(ctx.renderer);
    SDL_RenderCopy(ctx.renderer, ctx.texture, NULL, NULL);
    SDL_RenderPresent(ctx.renderer);
    
    ctx.visual.frame++;
}

static void main_loop(void) {
    uint32_t frame_start;
    uint32_t frame_time;
    
    while (ctx.running) {
        frame_start = SDL_GetTicks();
        
        handle_events();
        
        // TODO: Get audio timing and sync visuals
        // unsigned int audio_time = get_audio_time_ms();
        // float rms = get_rms_level(frame_idx);
        
        render_frame();
        
        // Frame rate limiting
        frame_time = SDL_GetTicks() - frame_start;
        if (frame_time < FRAME_TIME_MS) {
            SDL_Delay(FRAME_TIME_MS - frame_time);
        }
    }
}

int main(int argc, char *argv[]) {
    printf("🌋 NUCLEAR CHAOS MODE VISUAL SYSTEM 💥\n");
    printf("Resolution: %dx%d @ %d FPS\n", VIS_WIDTH, VIS_HEIGHT, VIS_FPS);
    
    // Check for audio file argument
    if (argc < 2) {
        printf("Usage: %s <audio_file.wav>\n", argv[0]);
        return 1;
    }
    
    // Load audio file for visual analysis
    if (!load_wav_file(argv[1])) {
        printf("Error: Could not load audio file: %s\n", argv[1]);
        return 1;
    }
    
    printf("Successfully loaded audio file!\n");
    print_audio_info();
    
    if (!init_sdl()) {
        cleanup_sdl();
        return 1;
    }
    
    printf("SDL2 initialized successfully\n");
    printf("🔥 CHAOS MODE ACTIVE - PREPARE FOR MADNESS! 🔥\n");
    printf("Press ESC to exit\n");
    
    // Initialize audio-visual mapping
    init_audio_visual_mapping();
    
    main_loop();
    
    cleanup_sdl();
    cleanup_audio_data();
    printf("Visual system shutdown complete\n");
    return 0;
}
