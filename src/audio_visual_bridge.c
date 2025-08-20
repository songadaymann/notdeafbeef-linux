#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <stdbool.h>
#include <time.h>

// External audio analysis functions (from wav_reader.c)
extern float get_audio_rms_for_frame(int frame);
extern float get_max_rms(void);
extern float get_audio_bpm(void);

// External ASM visual functions we can trigger
extern void spawn_explosion_asm(float cx, float cy, float base_hue);
extern void spawn_bass_hit_asm(float cx, float cy, int shape_type, float base_hue);

// Audio-Visual mapping state
typedef struct {
    float last_rms;
    float rms_smoothed;
    float beat_phase;
    float bass_energy;
    float treble_energy;
    int last_beat_frame;
    int explosion_cooldown;
    int bass_hit_cooldown;
} audio_visual_state_t;

static audio_visual_state_t av_state = {0};

// Initialize audio-visual mapping
void init_audio_visual_mapping(void) {
    av_state.last_rms = 0.0f;
    av_state.rms_smoothed = 0.0f;
    av_state.beat_phase = 0.0f;
    av_state.bass_energy = 0.0f;
    av_state.treble_energy = 0.0f;
    av_state.last_beat_frame = 0;
    av_state.explosion_cooldown = 0;
    av_state.bass_hit_cooldown = 0;
}

// Smooth RMS values to avoid visual jitter
float get_smoothed_audio_level(int frame) {
    float raw_rms = get_audio_rms_for_frame(frame);
    float max_rms = get_max_rms();
    float normalized = (max_rms > 0.0f) ? (raw_rms / max_rms) : 0.0f;
    
    // Exponential smoothing
    float alpha = 0.1f; // Smoothing factor
    av_state.rms_smoothed = alpha * normalized + (1.0f - alpha) * av_state.rms_smoothed;
    
    return fmaxf(0.0f, fminf(1.0f, av_state.rms_smoothed));
}

// 🔥 HAIR-TRIGGER BEAT DETECTION - Maximum reactivity! 🔥
bool detect_beat_onset(int frame) {
    float current_rms = get_audio_rms_for_frame(frame);
    float max_rms = get_max_rms();
    float normalized = (max_rms > 0.0f) ? (current_rms / max_rms) : 0.0f;
    
    // CHAOS MODE: Much more sensitive beat detection!
    float threshold = 0.05f; // Way lower threshold = more beats detected!
    float ratio = (av_state.last_rms > 0.0f) ? (normalized / av_state.last_rms) : 1.0f;
    
    bool is_onset = (ratio > (1.0f + threshold)) && 
                    (normalized > 0.1f) &&  // Much lower level needed
                    (frame - av_state.last_beat_frame > 3); // Shorter gap = more frequent beats
    
    if (is_onset) {
        av_state.last_beat_frame = frame;
    }
    
    av_state.last_rms = normalized;
    return is_onset;
}

// Calculate beat phase for cycling effects
float get_beat_phase(int frame, float bpm) {
    float time_sec = frame / 60.0f; // Assuming 60 FPS
    float beat_duration = 60.0f / bpm;
    return fmod(time_sec, beat_duration) / beat_duration;
}

// Get bass frequency energy (low frequencies)
float get_bass_energy(int frame) {
    // Simplified: use RMS as proxy for bass energy
    // In a real system, this would use FFT analysis
    float rms = get_audio_rms_for_frame(frame);
    float max_rms = get_max_rms();
    float normalized = (max_rms > 0.0f) ? (rms / max_rms) : 0.0f;
    
    // Simulate bass emphasis
    av_state.bass_energy = 0.9f * av_state.bass_energy + 0.1f * normalized;
    return av_state.bass_energy;
}

// Get treble frequency energy (high frequencies)  
float get_treble_energy(int frame) {
    // Simplified: use inverted bass energy as proxy
    float bass = get_bass_energy(frame);
    float rms = get_audio_rms_for_frame(frame);
    float max_rms = get_max_rms();
    float normalized = (max_rms > 0.0f) ? (rms / max_rms) : 0.0f;
    
    // Simulate treble as complement to bass
    av_state.treble_energy = normalized - bass * 0.5f;
    return fmaxf(0.0f, av_state.treble_energy);
}

// 💥 NUCLEAR PARTICLE MAYHEM 💥
void update_audio_reactive_particles(int frame, float base_hue) {
    float audio_level = get_smoothed_audio_level(frame);
    
    // 🔥 BEAT EXPLOSION FRENZY - Multiple explosions per beat!
    if (detect_beat_onset(frame)) {
        int explosion_count = (int)(audio_level * 15) + 5; // 5-20 explosions per beat!
        for (int i = 0; i < explosion_count; i++) {
            float cx = rand() % 800; // Entire screen width
            float cy = rand() % 600; // Entire screen height
            float chaos_hue = fmod(base_hue + (i * 0.08f) + (rand() % 100 / 100.0f), 1.0f);
            spawn_explosion_asm(cx, cy, chaos_hue);
        }
    }
    
    // 🌊 CONSTANT AUDIO-REACTIVE EXPLOSIONS - No cooldowns!
    if (frame % (int)fmax(1, 6 - audio_level * 5) == 0) {
        for (int i = 0; i < 6; i++) {
            float x = (i * 133) % 800; // Distributed across screen
            float y = 100 + (rand() % 400);
            float hue = fmod(frame * 0.03f + i * 0.16f, 1.0f);
            spawn_explosion_asm(x, y, hue);
        }
    }
    
    // 🌈 RAINBOW SPIRAL MADNESS
    if (frame % 3 == 0) {
        for (int i = 0; i < 8; i++) {
            float angle = (frame * 0.1f) + (i * 0.785f); // 8 spokes
            float radius = 150 + (audio_level * 100);
            float cx = 400 + cos(angle) * radius;
            float cy = 300 + sin(angle) * radius;
            if (cx >= 0 && cx < 800 && cy >= 0 && cy < 600) {
                spawn_explosion_asm(cx, cy, i / 8.0f); // Perfect rainbow
            }
        }
    }
}

// 🔯 GEOMETRIC SHAPE STORM 🔯
void update_audio_reactive_bass_hits(int frame, float base_hue) {
    float bass_energy = get_bass_energy(frame);
    float audio_level = get_smoothed_audio_level(frame);
    
    // 🌪️ SHAPE SPAM FRENZY - Any audio activity triggers shapes!
    if (audio_level > 0.02f) { // Super low threshold = constant shapes
        int shape_count = (int)(bass_energy * 12) + 2; // 2-14 shapes
        for (int i = 0; i < shape_count; i++) {
            float cx = (i * 80 + frame * 2) % 800; // Moving across screen
            float cy = 100 + (rand() % 400);
            int shape_type = (frame + i) % 3; // Cycling through all shapes
            float shape_hue = fmod(base_hue + (i * 0.12f), 1.0f);
            spawn_bass_hit_asm(cx, cy, shape_type, shape_hue);
        }
    }
    
    // 💫 GEOMETRIC GRID EXPLOSION
    if (bass_energy > 0.3f) {
        for (int x = 0; x < 6; x++) {
            for (int y = 0; y < 4; y++) {
                float grid_x = 50 + x * 120;
                float grid_y = 75 + y * 125;
                int shape = (x + y + frame/10) % 3;
                float hue = fmod((x + y) * 0.1f + base_hue, 1.0f);
                spawn_bass_hit_asm(grid_x, grid_y, shape, hue);
            }
        }
    }
    
    // 🎯 PULSING CONCENTRIC SHAPES
    if (frame % 5 == 0) {
        for (int ring = 0; ring < 4; ring++) {
            float radius = 80 + ring * 60 + bass_energy * 50;
            for (int i = 0; i < 6; i++) {
                float angle = i * 1.047f + frame * 0.05f; // 6 shapes per ring
                float cx = 400 + cos(angle) * radius;
                float cy = 300 + sin(angle) * radius;
                if (cx >= 0 && cx < 800 && cy >= 0 && cy < 600) {
                    spawn_bass_hit_asm(cx, cy, ring % 3, ring * 0.25f);
                }
            }
        }
    }
}

// ⚡ MAXIMUM DIGITAL CHAOS ⚡
float get_audio_driven_glitch_intensity(int frame) {
    float treble = get_treble_energy(frame);
    float bass = get_bass_energy(frame);
    float audio_level = get_smoothed_audio_level(frame);
    
    // 🔥 EXTREME GLITCH MODE - Way more intense!
    float base_chaos = 0.5f; // Much higher base intensity
    float audio_chaos = powf(audio_level + treble + bass, 0.4f) * 2.0f; // Amplified chaos
    
    // 💥 Beat-synchronized glitch explosions
    float bpm = get_audio_bpm();
    float beat_phase = get_beat_phase(frame, bpm);
    float beat_explosion = (beat_phase < 0.15f) ? 1.0f : 0.0f; // Massive beat spikes
    
    // 🌊 Oscillating chaos waves
    float chaos_wave = sin(frame * 0.1f) * 0.3f + 0.3f;
    
    float total_chaos = base_chaos + audio_chaos + beat_explosion + chaos_wave;
    return fmaxf(0.0f, fminf(3.0f, total_chaos)); // Allow up to 3x normal intensity!
}

// 🌈 PSYCHEDELIC COLOR MADNESS 🌈
float get_audio_driven_hue_shift(int frame) {
    float bpm = get_audio_bpm();
    float time_sec = frame / 60.0f;
    float audio_level = get_smoothed_audio_level(frame);
    float bass = get_bass_energy(frame);
    
    // 🔥 RAPID COLOR CYCLING - Much faster than before!
    float speed_multiplier = 5.0f + audio_level * 10.0f; // 5x-15x faster!
    float base_rotation = fmod(time_sec * speed_multiplier * 0.02f, 1.0f);
    
    // 💫 AUDIO-REACTIVE COLOR JUMPS
    float bass_jump = bass * 0.3f * sin(time_sec * 8.0f);
    float treble_flicker = get_treble_energy(frame) * 0.2f * sin(time_sec * 20.0f);
    
    // 🌊 CHAOS WAVE MODULATION
    float chaos_wave1 = sin(time_sec * 3.0f) * 0.15f;
    float chaos_wave2 = cos(time_sec * 7.0f) * 0.1f;
    
    float total_hue = base_rotation + bass_jump + treble_flicker + chaos_wave1 + chaos_wave2;
    return fmod(total_hue, 1.0f);
}

// 🌋 NUCLEAR CHAOS MODE - EVERYTHING AT MAXIMUM! 🌋
void update_audio_visual_effects(int frame, float base_hue) {
    // Seed random for consistent chaos across frames
    srand(frame / 10);
    
    // Update chaos particle effects
    update_audio_reactive_particles(frame, base_hue);
    
    // Update chaos bass hits
    update_audio_reactive_bass_hits(frame, base_hue);
    
    // 🎆 BONUS CHAOS EFFECTS!
    float audio_level = get_smoothed_audio_level(frame);
    
    // 💥 SCREEN EDGE EXPLOSIONS
    if (frame % 8 == 0) {
        // Top edge
        for (int i = 0; i < 5; i++) {
            spawn_explosion_asm(i * 160, 20, fmod(i * 0.2f + frame * 0.01f, 1.0f));
        }
        // Bottom edge  
        for (int i = 0; i < 5; i++) {
            spawn_explosion_asm(i * 160, 580, fmod(i * 0.2f + frame * 0.01f + 0.5f, 1.0f));
        }
    }
    
    // 🌪️ AUDIO-REACTIVE VORTEX
    if (audio_level > 0.3f) {
        for (int i = 0; i < 12; i++) {
            float angle = i * 0.524f + frame * 0.05f; // 12 spokes
            float radius = 200 + audio_level * 150;
            float x = 400 + cos(angle) * radius;
            float y = 300 + sin(angle) * radius;
            if (x >= 0 && x < 800 && y >= 0 && y < 600) {
                spawn_bass_hit_asm(x, y, i % 3, i / 12.0f);
            }
        }
    }
}

// Get current audio analysis values for debugging/display
void get_audio_analysis_values(float *rms, float *bass, float *treble, float *glitch) {
    static int last_frame = -1;
    static int current_frame = 0;
    
    // Simple frame counter
    if (last_frame != current_frame) {
        current_frame++;
        last_frame = current_frame;
    }
    
    *rms = get_smoothed_audio_level(current_frame);
    *bass = get_bass_energy(current_frame);
    *treble = get_treble_energy(current_frame);
    *glitch = get_audio_driven_glitch_intensity(current_frame);
}
