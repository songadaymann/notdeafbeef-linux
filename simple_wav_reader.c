
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

// WAV file header structure
typedef struct {
    char riff[4];           // "RIFF"
    uint32_t chunk_size;    // File size - 8
    char wave[4];           // "WAVE"
    char fmt[4];            // "fmt "
    uint32_t fmt_size;      // Format chunk size
    uint16_t audio_format;  // Audio format (1 = PCM)
    uint16_t num_channels;  // Number of channels
    uint32_t sample_rate;   // Sample rate
    uint32_t byte_rate;     // Byte rate
    uint16_t block_align;   // Block align
    uint16_t bits_per_sample; // Bits per sample
    char data[4];           // "data"
    uint32_t data_size;     // Data size
} wav_header_t;

// Audio analysis data
typedef struct {
    int16_t *samples;       // Raw audio samples (stereo interleaved)
    uint32_t sample_count;  // Total samples (left + right)
    uint32_t frame_count;   // Number of stereo frames
    uint32_t sample_rate;   // Sample rate (Hz)
    float duration;         // Duration in seconds
} audio_data_t;

static audio_data_t audio_data = {0};

// Simple audio level calculation (RMS)
float calculate_audio_level_at_frame(int frame_number, float fps) {
    if (!audio_data.samples || audio_data.frame_count == 0) {
        return 0.2f; // Default level
    }
    
    float time_seconds = frame_number / fps;
    uint32_t sample_index = (uint32_t)(time_seconds * audio_data.sample_rate);
    
    if (sample_index >= audio_data.frame_count) {
        sample_index = audio_data.frame_count - 1;
    }
    
    // Calculate RMS over a small window
    uint32_t window_size = audio_data.sample_rate / 30; // ~33ms window
    uint32_t start_sample = (sample_index > window_size/2) ? sample_index - window_size/2 : 0;
    uint32_t end_sample = start_sample + window_size;
    if (end_sample > audio_data.frame_count) {
        end_sample = audio_data.frame_count;
        start_sample = (end_sample > window_size) ? end_sample - window_size : 0;
    }
    
    float sum_squares = 0.0f;
    uint32_t count = 0;
    
    for (uint32_t i = start_sample; i < end_sample; i++) {
        float left = audio_data.samples[i * 2] / 32768.0f;
        float right = audio_data.samples[i * 2 + 1] / 32768.0f;
        float mono = (left + right) * 0.5f;
        sum_squares += mono * mono;
        count++;
    }
    
    if (count == 0) return 0.2f;
    
    float rms = sqrtf(sum_squares / count);
    return fminf(1.0f, fmaxf(0.0f, rms * 3.0f)); // Scale and clamp
}

// Load WAV file
bool load_wav_file(const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        printf("Failed to open WAV file: %s\n", filename);
        return false;
    }
    
    wav_header_t header;
    if (fread(&header, sizeof(header), 1, file) != 1) {
        printf("Failed to read WAV header\n");
        fclose(file);
        return false;
    }
    
    // Basic validation
    if (strncmp(header.riff, "RIFF", 4) != 0 || 
        strncmp(header.wave, "WAVE", 4) != 0 ||
        strncmp(header.data, "data", 4) != 0) {
        printf("Invalid WAV file format\n");
        fclose(file);
        return false;
    }
    
    if (header.audio_format != 1 || header.bits_per_sample != 16) {
        printf("Unsupported WAV format (need 16-bit PCM)\n");
        fclose(file);
        return false;
    }
    
    // Allocate and read sample data
    uint32_t sample_count = header.data_size / 2; // 16-bit samples
    audio_data.samples = malloc(header.data_size);
    if (!audio_data.samples) {
        printf("Failed to allocate memory for samples\n");
        fclose(file);
        return false;
    }
    
    if (fread(audio_data.samples, header.data_size, 1, file) != 1) {
        printf("Failed to read sample data\n");
        free(audio_data.samples);
        audio_data.samples = NULL;
        fclose(file);
        return false;
    }
    
    audio_data.sample_count = sample_count;
    audio_data.frame_count = sample_count / header.num_channels;
    audio_data.sample_rate = header.sample_rate;
    audio_data.duration = (float)audio_data.frame_count / header.sample_rate;
    
    fclose(file);
    
    printf("Loaded WAV: %d samples, %.2f seconds, %d Hz\n", 
           audio_data.frame_count, audio_data.duration, audio_data.sample_rate);
    
    return true;
}

// Additional functions needed by audio_visual_bridge.c
float get_audio_duration() {
    return audio_data.duration;
}

bool is_audio_finished() {
    return false; // For frame generation, never consider audio "finished"
}

void print_audio_info() {
    printf("Audio info: %.2f seconds, %d Hz, %d frames\n", 
           audio_data.duration, audio_data.sample_rate, audio_data.frame_count);
}

float get_audio_rms_for_frame(int frame_number, float fps) {
    return calculate_audio_level_at_frame(frame_number, fps);
}

float get_max_rms() {
    return 1.0f; // Assume normalized
}

float get_audio_bpm() {
    return 120.0f; // Default BPM
}

// Cleanup
void cleanup_audio_data() {
    if (audio_data.samples) {
        free(audio_data.samples);
        audio_data.samples = NULL;
    }
    audio_data.sample_count = 0;
    audio_data.frame_count = 0;
    audio_data.sample_rate = 0;
    audio_data.duration = 0.0f;
}
