#include "../include/coreaudio.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Linux-compatible audio implementation (no-op for headless cloud deployment)
// This replaces CoreAudio for server environments where audio playback isn't needed

typedef struct {
    audio_callback_t user_callback;
    void* user_data;
    uint32_t buffer_size_frames;
    uint32_t sample_rate;
    int running;
} audio_state_t;

static audio_state_t g_audio_state = {0};

int audio_init(uint32_t sr, uint32_t buffer_size, audio_callback_t callback, void* user_data)
{
    g_audio_state.user_callback = callback;
    g_audio_state.user_data = user_data;
    g_audio_state.buffer_size_frames = buffer_size;
    g_audio_state.sample_rate = sr;
    g_audio_state.running = 0;
    
    printf("Linux audio initialized (headless mode) - SR: %d, Buffer: %d\n", sr, buffer_size);
    return 0;
}

int audio_start(void)
{
    g_audio_state.running = 1;
    printf("Linux audio started (headless mode)\n");
    return 0;
}

int audio_stop(void)
{
    g_audio_state.running = 0;
    printf("Linux audio stopped (headless mode)\n");
    return 0;
}

void audio_cleanup(void)
{
    g_audio_state.running = 0;
    printf("Linux audio cleanup (headless mode)\n");
}

// Helper function to simulate audio processing for testing
int audio_process_buffer_once(float* buffer, uint32_t frames)
{
    if (g_audio_state.user_callback && buffer) {
        g_audio_state.user_callback(buffer, frames, g_audio_state.user_data);
        return 0;
    }
    return 1;
}
