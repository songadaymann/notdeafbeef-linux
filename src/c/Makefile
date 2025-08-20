
# Simple build script – Phase 0 scaffolding

CC := clang
# Detect OS for SDL paths
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  SDL_CFLAGS := $(shell sdl2-config --cflags)
  SDL_LIBS   := $(shell sdl2-config --libs)
else ifeq ($(UNAME_S),Linux)
  SDL_CFLAGS := $(shell pkg-config --cflags sdl2 2>/dev/null || echo "")
  SDL_LIBS   := $(shell pkg-config --libs sdl2 2>/dev/null || echo "")
endif

# Determine host arch first
ARCH := $(shell uname -m)

# Detect request for cross-compilation (set CROSS=1 from CLI)
ifndef CROSS
CROSS := 0
endif

# If we are on an x86_64 host *and* not explicitly cross-compiling, disable ASM
ifeq ($(ARCH),x86_64)
  ifeq ($(CROSS),0)
    USE_ASM := 0
  endif
endif

# On Linux ARM64, enable ASM by default
ifeq ($(ARCH),aarch64)
  USE_ASM := 1
endif

# If CROSS=1, enforce arm64 code-gen flags
ifeq ($(CROSS),1)
  USE_ASM := 1
  # Detect host OS for proper targeting
  ifeq ($(UNAME_S),Darwin)
    CFLAGS += -target arm64-apple-macos13
  else ifeq ($(UNAME_S),Linux)
    CFLAGS += -march=armv8-a
  endif
endif

# Default USE_ASM detection if not already set
ifndef USE_ASM
  # Simple architecture detection - on ARM64 machines, enable ASM by default
  ifeq ($(ARCH),arm64)
  USE_ASM := 1
  else
  USE_ASM := 0
  endif
endif

ifeq ($(findstring GENERATOR_ASM,$(VOICE_ASM)),)
  GENERATOR_IS_C := 1
else
  GENERATOR_IS_C := 0
endif

# base flags
CFLAGS := -std=c11 -Wall -Wextra -O2 -Iinclude $(SDL_CFLAGS)

# Enhanced debug flags for LLDB debugging with mixed C+assembly (mentioned in roadmap)
ifeq ($(DEBUG),1)
CFLAGS += -g -O0 -fstandalone-debug -fno-omit-frame-pointer
endif

# float32_t helper macro (typedef-like).  The NEON compile unit undefines it to avoid clash.
CFLAGS += -Dfloat32_t=float

# Append profiling flags when PROFILE=1
ifeq ($(PROFILE),1)
CFLAGS += -pg -fno-omit-frame-pointer
endif

# Optional Address Sanitizer support (enable via ASAN=1)
ifeq ($(ASAN),1)
CFLAGS += -fsanitize=address -fno-omit-frame-pointer
LDFLAGS += -fsanitize=address
endif

# Platform-specific linking flags
ifeq ($(UNAME_S),Darwin)
  LDFLAGS := -framework AudioToolbox -framework CoreFoundation -framework OpenGL $(SDL_LIBS)
else ifeq ($(UNAME_S),Linux)
  LDFLAGS := $(SDL_LIBS) -lm -lpthread
endif

# BEGIN ASM SUPPORT
ifeq ($(USE_ASM),1)
ASM_DIR := ../../asm/active
ASM_SRC := $(ASM_DIR)/euclid.s $(ASM_DIR)/limiter.s $(ASM_DIR)/noise.s $(ASM_DIR)/osc_shapes.s $(ASM_DIR)/osc_sine.s $(ASM_DIR)/generator.s
# If the VOICE_ASM variable is provided, include only the requested voice assembly files to
# avoid duplicate symbol errors with the C fallback implementations.
ifneq ($(origin VOICE_ASM), undefined)
# 1) Remove all per-voice assembly files from the list
ASM_SRC := $(filter-out $(ASM_DIR)/kick.s $(ASM_DIR)/snare.s $(ASM_DIR)/hat.s $(ASM_DIR)/melody.s $(ASM_DIR)/delay.s $(ASM_DIR)/fm_voice.s $(ASM_DIR)/exp4_ps_asm.s $(ASM_DIR)/sin4_ps_asm.s,$(ASM_SRC))

# 2) Re-add only those explicitly requested via VOICE_ASM.
ifneq ($(findstring KICK_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/kick.s
endif
ifneq ($(findstring SNARE_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/snare.s
endif
ifneq ($(findstring HAT_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/hat.s
endif
ifneq ($(findstring MELODY_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/melody.s
endif
ifneq ($(findstring DELAY_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/delay.s
endif
ifneq ($(findstring FM_VOICE_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/fm_voice.s $(ASM_DIR)/exp4_ps_asm.s $(ASM_DIR)/sin4_ps_asm.s
endif
endif

# --- Assembly generator (generator_process) opt-in -----------------------
# By default we now EXCLUDE generator.s so that the stable C implementation
# is used.  If you really want the work-in-progress assembly version, pass
#   VOICE_ASM="GENERATOR_ASM"
# or include GENERATOR_ASM in the existing list.

# 1) Always remove generator.s first
ASM_SRC := $(filter-out $(ASM_DIR)/generator.s,$(ASM_SRC))

# 2) Re-add only if user explicitly asks for it
ifneq ($(findstring GENERATOR_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/generator.s
endif

ASM_OBJ := $(ASM_SRC:.s=.o)
# Add math objects only if FM voice assembly is enabled
ifeq ($(findstring -DFM_VOICE_ASM,$(CFLAGS)),-DFM_VOICE_ASM)
ASM_OBJ += $(ASM_DIR)/exp4_ps_asm.o $(ASM_DIR)/sin4_ps_asm.o
endif
# per-module ASM optimisation flags
CFLAGS += -DOSC_SINE_ASM -DOSC_SHAPES_ASM
# Voice assembly macros. By default enable all voices that have an ASM version implemented.
# For debugging you can override this via:
#    make segment VOICE_ASM="KICK_ASM"            # only kick in ASM, others in C
#    make segment VOICE_ASM="KICK_ASM SNARE_ASM"  # kick + snare in ASM
# If VOICE_ASM is undefined we fall back to enabling every voice (legacy behaviour).
ifeq ($(origin VOICE_ASM), undefined)
CFLAGS += -DKICK_ASM -DSNARE_ASM -DHAT_ASM -DMELODY_ASM -DDELAY_ASM
ASM_SRC += $(ASM_DIR)/kick.s $(ASM_DIR)/snare.s $(ASM_DIR)/hat.s $(ASM_DIR)/melody.s $(ASM_DIR)/delay.s
else
CFLAGS += $(addprefix -D,$(VOICE_ASM))
# Also add corresponding assembly sources for specified voices
ifneq ($(findstring KICK_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/kick.s
endif
ifneq ($(findstring SNARE_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/snare.s
endif
ifneq ($(findstring HAT_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/hat.s
endif
ifneq ($(findstring MELODY_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/melody.s
endif
ifneq ($(findstring DELAY_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/delay.s
endif
ifneq ($(findstring FM_VOICE_ASM,$(VOICE_ASM)),)
ASM_SRC += $(ASM_DIR)/fm_voice.s $(ASM_DIR)/exp4_ps_asm.s $(ASM_DIR)/sin4_ps_asm.s
endif
endif
# CFLAGS += -DFM_VOICE_ASM
else
ASM_DIR :=
ASM_SRC :=
ASM_OBJ :=
endif
# END ASM SUPPORT

# Detect whether the assembly delay implementation is included
DELAY_ASM_PRESENT := $(filter $(ASM_DIR)/delay.s,$(ASM_SRC))
# Detect whether the assembly limiter implementation is included
LIMITER_ASM_PRESENT := $(filter $(ASM_DIR)/limiter.s,$(ASM_SRC))
# Detect generator assembly presence
GENERATOR_ASM_PRESENT := $(filter $(ASM_DIR)/generator.s,$(ASM_SRC))

# If the assembly generator provides its own RMS helper, tell C sources not to compile the fallback
ifeq ($(GENERATOR_ASM_PRESENT),$(ASM_DIR)/generator.s)
CFLAGS += -DGENERATOR_RMS_ASM_PRESENT
endif

ifeq ($(USE_ASM),1)
  # Only add cross-compilation flags if we're on x86_64 and cross-compiling
  ifeq ($(ARCH),x86_64)
    ifeq ($(CROSS),1)
      # Detect host OS for proper targeting
      ifeq ($(UNAME_S),Darwin)
        CFLAGS += -target arm64-apple-macos13
      else ifeq ($(UNAME_S),Linux)
        CFLAGS += -march=armv8-a
      endif
    endif
  endif
# fm_voice_neon.c superseded by hand-written assembly; skip this object
NEON_OBJ :=
else
NEON_OBJ :=
endif

OBJ := src/main.o src/wav_writer.o src/euclid.o src/osc.o src/kick.o src/snare.o src/hat.o src/melody.o src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/event_queue.o src/simple_voice.o
BIN := bin/euclid
TEST_BIN := bin/gen_sine
TONE_BIN := bin/gen_tones
NOISE_BIN := bin/gen_noise_delay
KICK_BIN := bin/gen_kick
SNARE_BIN := bin/gen_snare
HAT_BIN := bin/gen_hat
MELODY_BIN := bin/gen_melody
FM_BIN := bin/gen_fm
SEG_BIN := bin/segment
SEG_TEST_BIN := bin/segment_test
DRUMS_BIN := bin/segment_drums
DRUMS_MEL_BIN := bin/segment_drums_mel
DRUMS_BASS_BIN := bin/segment_drums_bass
BELLS_BIN := bin/gen_bells
CALM_BIN := bin/gen_calm
QUANTUM_BIN := bin/gen_quantum
PLUCK_BIN := bin/gen_pluck
BASS_BIN := bin/gen_bass
BASSQ_BIN := bin/gen_bass_quantum
BASSP_BIN := bin/gen_bass_plucky
MELODY_DEBUG_BIN := bin/melody_debug_test
FM_DEBUG_BIN := bin/fm_debug_test

SEG_OBJ := src/segment.o src/wav_writer.o
SEG_TEST_OBJ := src/segment_test.o src/wav_writer.o

# Include C euclid.o only when not using assembly (to avoid duplicate symbols)
ifneq ($(USE_ASM),1)
SEG_OBJ += src/euclid.o
SEG_TEST_OBJ += src/euclid.o
endif

# -----------------------------------------------------------------
# Conditional C object inclusion depending on whether ASM version
# of each voice/effect is present (prevents duplicate symbols).
# -----------------------------------------------------------------
# Detect per-voice ASM presence
KICK_ASM_PRESENT   := $(filter $(ASM_DIR)/kick.s,$(ASM_SRC))
SNARE_ASM_PRESENT  := $(filter $(ASM_DIR)/snare.s,$(ASM_SRC))
HAT_ASM_PRESENT    := $(filter $(ASM_DIR)/hat.s,$(ASM_SRC))
MELODY_ASM_PRESENT := $(filter $(ASM_DIR)/melody.s,$(ASM_SRC))

# Rebuild GEN_OBJ list: start with ASM objects and common C helpers
# Exclude src/osc.o when ASM oscillators are present to avoid duplicate symbols
ifeq ($(USE_ASM),1)
GEN_OBJ := $(ASM_OBJ) $(NEON_OBJ) src/fm_presets.o \
          src/event_queue.o src/simple_voice.o
else
GEN_OBJ := $(ASM_OBJ) src/osc.o $(NEON_OBJ) src/fm_presets.o \
          src/event_queue.o src/simple_voice.o
endif

# Add FM voice object (hybrid ASM+C for helpers, or pure C fallback)
ifeq ($(findstring -DFM_VOICE_ASM,$(CFLAGS)),-DFM_VOICE_ASM)
GEN_OBJ += $(ASM_DIR)/fm_voice.o src/fm_voice.o
else
GEN_OBJ += src/fm_voice.o
endif

# Nuclear refactor flag - set to 1 to remove all C voice fallbacks  
NO_C_VOICES := 0
ifeq ($(NO_C_VOICES),1)
CFLAGS += -DNO_C_VOICES=1
endif

# Selective melody delay is now the permanent behavior
# (no longer requires conditional compilation)

# Always include per-voice C modules for init/trigger helpers.
# When NO_C_VOICES=0: Their process() functions work as fallbacks via #ifndef guards
# When NO_C_VOICES=1: Only init/trigger helpers are used, process() functions disabled
ifeq ($(NO_C_VOICES),1)
  # With NO_C_VOICES=1, all voices must have ASM implementations
  VOICE_LIST := kick snare hat melody
  $(foreach voice,$(VOICE_LIST),\
    $(if $(findstring $(shell echo $(voice) | tr '[:lower:]' '[:upper:]')_ASM,$(VOICE_ASM)),,\
      $(error NO_C_VOICES=1 but $(voice) ASM implementation missing)\
    )\
  )
endif
GEN_OBJ += src/kick.o src/snare.o src/hat.o src/melody.o

# Delay C fallback only when ASM version *not* present (it contains only the
# process implementation guarded by #ifndef DELAY_ASM; omitting it when the
# ASM version is linked avoids a redundant empty object).
ifndef DELAY_ASM_PRESENT
GEN_OBJ += src/delay.o
endif

# Generator: always include C for generator_init (compiled with -DGENERATOR_ASM)
GEN_OBJ += src/generator.o

# Limiter C fallback
ifndef LIMITER_ASM_PRESENT
GEN_OBJ += src/limiter.o
endif

# Include minimal generator_step stub for trigger functionality
GEN_OBJ += src/generator_step.o

# Platform-specific audio objects
ifeq ($(UNAME_S),Darwin)
  AUDIO_OBJ := src/coreaudio.o
else ifeq ($(UNAME_S),Linux)
  AUDIO_OBJ := src/linuxaudio.o
endif

REALTIME_OBJ := src/main_realtime.o $(AUDIO_OBJ) src/video.o src/raster.o src/terrain.o src/particles.o src/shapes.o src/crt_fx.o

REALTIME_BIN := bin/realtime

# Timeline export tool (link only minimal C objects; avoid ASM-only process fns)
TIMELINE_OBJ := src/export_timeline.o \
                src/generator.o src/event_queue.o src/fm_presets.o \
                src/kick.o src/snare.o src/hat.o src/melody.o src/fm_voice.o \
                src/delay.o src/limiter.o
TIMELINE_BIN := bin/export_timeline

all: $(SEG_BIN) $(REALTIME_BIN) $(TIMELINE_BIN)

$(SEG_BIN): $(SEG_OBJ) $(GEN_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(SEG_TEST_BIN): $(SEG_TEST_OBJ) $(GEN_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

bin/long_loop_test: long_loop_test.c $(GEN_OBJ) src/wav_writer.o $(ASM_OBJ) ../asm/active/generator.o ../asm/active/kick.o ../asm/active/snare.o ../asm/active/hat.o ../asm/active/melody.o ../asm/active/fm_voice.o ../asm/active/delay.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(REALTIME_BIN): $(REALTIME_OBJ) $(GEN_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(TIMELINE_BIN): $(TIMELINE_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

# Individual generator builds - conditional to avoid duplicate symbols
ifeq ($(USE_ASM),1)
$(TEST_BIN): src/gen_sine.c src/osc.o $(ASM_OBJ) src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(TONE_BIN): src/gen_tones.c src/osc.o $(ASM_OBJ) src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(NOISE_BIN): src/gen_noise_delay.c src/osc.o src/delay.o $(ASM_OBJ) src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(KICK_BIN): src/gen_kick.c src/kick.o $(ASM_OBJ) src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(SNARE_BIN): src/gen_snare.c src/snare.o $(ASM_OBJ) src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(HAT_BIN): src/gen_hat.c src/hat.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(MELODY_BIN): src/gen_melody.c src/melody.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(FM_BIN): src/gen_fm.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^
else
$(TEST_BIN): src/gen_sine.c src/osc.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(TONE_BIN): src/gen_tones.c src/osc.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(NOISE_BIN): src/gen_noise_delay.c src/osc.o src/delay.o src/noise.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(KICK_BIN): src/gen_kick.c src/kick.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(SNARE_BIN): src/gen_snare.c src/snare.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(HAT_BIN): src/gen_hat.c src/hat.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(MELODY_BIN): src/gen_melody.c src/melody.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(FM_BIN): src/gen_fm.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^
endif

$(DRUMS_BIN): src/segment.c $(SEG_OBJ) | bin
	$(CC) $(CFLAGS) -DDRUMS_ONLY -o $@ src/segment.c $(SEG_OBJ)

$(DRUMS_MEL_BIN): src/segment.c $(SEG_OBJ) | bin
	$(CC) $(CFLAGS) -DNO_FM -o $@ src/segment.c $(SEG_OBJ)

$(DRUMS_BASS_BIN): src/segment.c $(SEG_OBJ) | bin
	$(CC) $(CFLAGS) -DNO_MID_FM -o $@ src/segment.c $(SEG_OBJ)

# FM-related generator builds - conditional to avoid duplicate symbols
ifeq ($(USE_ASM),1)
$(BELLS_BIN): src/gen_bells.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(CALM_BIN): src/gen_calm.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(QUANTUM_BIN): src/gen_quantum.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(PLUCK_BIN): src/gen_pluck.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASS_BIN): src/gen_bass.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASSQ_BIN): src/gen_bass_quantum.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASSP_BIN): src/gen_bass_plucky.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o $(ASM_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(MELODY_DEBUG_BIN): src/melody_debug_test.c src/wav_writer.o $(GEN_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^

$(FM_DEBUG_BIN): src/fm_debug_test.c src/wav_writer.o $(GEN_OBJ) | bin
	$(CC) $(CFLAGS) -o $@ $^
else
$(BELLS_BIN): src/gen_bells.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(CALM_BIN): src/gen_calm.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(QUANTUM_BIN): src/gen_quantum.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(PLUCK_BIN): src/gen_pluck.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASS_BIN): src/gen_bass.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASSQ_BIN): src/gen_bass_quantum.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^

$(BASSP_BIN): src/gen_bass_plucky.c src/fm_voice.o $(NEON_OBJ) src/fm_presets.o src/wav_writer.o | bin
	$(CC) $(CFLAGS) -o $@ $^
endif

bin:
	@mkdir -p bin

# pattern rule for objects
src/%.o: src/%.c | src include
	$(CC) $(CFLAGS) -c $< -o $@

src include:
	@mkdir -p src include

$(ASM_DIR)/%.o: $(ASM_DIR)/%.s | $(ASM_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(ASM_DIR):
	@mkdir -p $(ASM_DIR)

.PHONY: clean
clean:
	rm -rf src/*.o bin src/euclid.o 2>/dev/null || true

.PHONY: sine
sine: $(TEST_BIN)
	$(TEST_BIN)
	@echo "Generated sine.wav"

.PHONY: tones
tones: $(TONE_BIN)
	$(TONE_BIN)
	@echo "Generated saw.wav square.wav triangle.wav"

.PHONY: delay
delay: $(NOISE_BIN)
	$(NOISE_BIN)
	@echo "Generated delay.wav"

.PHONY: kick
kick: $(KICK_BIN)
	$(KICK_BIN)
	@echo "Generated kick.wav"

.PHONY: snare
snare: $(SNARE_BIN)
	$(SNARE_BIN)
	@echo "Generated snare.wav"

.PHONY: hat
hat: $(HAT_BIN)
	$(HAT_BIN)
	@echo "Generated hat.wav"

.PHONY: melody
melody: $(MELODY_BIN)
	$(MELODY_BIN)
	@echo "Generated melody.wav"

.PHONY: fm
fm: clean $(FM_BIN)
	$(FM_BIN)
	@echo "Generated fm.wav"

.PHONY: fm_c
fm_c: clean
	$(MAKE) $(FM_BIN)
	$(FM_BIN)
	mv fm.wav fm_c.wav
	@echo "Generated fm_c.wav (C version)"

.PHONY: fm_asm
fm_asm: clean
	$(MAKE) $(FM_BIN) USE_ASM=1 VOICE_ASM="FM_VOICE_ASM"
	$(FM_BIN)
	mv fm.wav fm_asm.wav
	@echo "Generated fm_asm.wav (Assembly version)"

.PHONY: segment
segment: $(SEG_BIN)
ifndef NO_RUN
ifdef SEED
	$(SEG_BIN) $(SEED)
else
	$(SEG_BIN)
endif
	@echo "Generated segment.wav"
endif

.PHONY: segment_test
segment_test: $(SEG_TEST_BIN)
	@echo "Built segment_test. Usage: $(SEG_TEST_BIN) <category1> [category2] ..."

.PHONY: long_loop_test
long_loop_test: bin/long_loop_test
	@echo "Built long_loop_test. Usage: bin/long_loop_test [seed] [output.wav]"

.PHONY: melody_debug  
melody_debug: $(MELODY_DEBUG_BIN)
	$(MELODY_DEBUG_BIN)

.PHONY: fm_debug  
fm_debug: $(FM_DEBUG_BIN)
	$(FM_DEBUG_BIN)

.PHONY: drums
drums: $(DRUMS_BIN)
	$(DRUMS_BIN)
	@echo "Generated segment_drums.wav"

.PHONY: drums_mel
drums_mel: $(DRUMS_MEL_BIN)
	$(DRUMS_MEL_BIN)
	@echo "Generated segment_drums_mel.wav"

.PHONY: drums_bass
drums_bass: $(DRUMS_BASS_BIN)
	$(DRUMS_BASS_BIN)
	@echo "Generated segment_drums_bass.wav"

# =============================================================================
# VOICE DEBUGGING TARGETS - Individual and combination testing
# =============================================================================

# Individual ASM voice tests (using current ASM configuration)
.PHONY: test_kick_asm test_snare_asm test_hat_asm test_melody_asm test_fm_asm
test_kick_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav kick_asm_test.wav
	@echo "Generated kick_asm_test.wav (ASM kick only)"

test_snare_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM SNARE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav snare_asm_test.wav
	@echo "Generated snare_asm_test.wav (ASM snare only)"

test_hat_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM HAT_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav hat_asm_test.wav
	@echo "Generated hat_asm_test.wav (ASM hat only)"

test_melody_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM MELODY_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav melody_asm_test.wav
	@echo "Generated melody_asm_test.wav (ASM melody only)"

test_fm_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM FM_VOICE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav fm_asm_test.wav
	@echo "Generated fm_asm_test.wav (ASM FM only)"

# Drum combinations
.PHONY: test_drums_asm test_drums_c
test_drums_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav drums_asm_test.wav
	@echo "Generated drums_asm_test.wav (ASM drums only)"

test_drums_c: clean
	$(MAKE) segment USE_ASM=0 NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav drums_c_test.wav
	@echo "Generated drums_c_test.wav (C version reference)"

# Voice combinations (incremental building)
.PHONY: test_drums_melody test_drums_fm test_melody_fm
test_drums_melody: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav drums_melody_test.wav
	@echo "Generated drums_melody_test.wav (ASM drums + melody)"

test_drums_fm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM FM_VOICE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav drums_fm_test.wav
	@echo "Generated drums_fm_test.wav (ASM drums + FM)"

test_melody_fm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM MELODY_ASM FM_VOICE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav melody_fm_test.wav
	@echo "Generated melody_fm_test.wav (ASM melody + FM)"

# Effects testing
.PHONY: test_with_delay test_with_limiter test_no_effects
test_with_delay: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM FM_VOICE_ASM DELAY_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav with_delay_test.wav
	@echo "Generated with_delay_test.wav (voices + delay)"

test_with_limiter: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM FM_VOICE_ASM LIMITER_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav with_limiter_test.wav
	@echo "Generated with_limiter_test.wav (voices + limiter)"

test_no_effects: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM FM_VOICE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav no_effects_test.wav
	@echo "Generated no_effects_test.wav (voices only, no delay/limiter)"

# Complete configuration (what we just fixed)
.PHONY: test_full_asm
test_full_asm: clean
	$(MAKE) segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM DELAY_ASM FM_VOICE_ASM" NO_RUN=1
	$(SEG_BIN)
	cp seed_0xcafebabe.wav full_asm_test.wav
	@echo "Generated full_asm_test.wav (complete ASM pipeline)"

# Quick test suite - generates all individual voices for comparison
.PHONY: test_all_voices
test_all_voices: test_kick_asm test_snare_asm test_hat_asm test_melody_asm test_fm_asm test_drums_c
	@echo "Generated all individual voice tests:"
	@echo "  kick_asm_test.wav snare_asm_test.wav hat_asm_test.wav"
	@echo "  melody_asm_test.wav fm_asm_test.wav drums_c_test.wav"

# Help target for debugging
.PHONY: help_debug
help_debug:
	@echo "Voice Debugging Targets:"
	@echo ""
	@echo "Individual Voices (ASM):"
	@echo "  make test_kick_asm     → kick_asm_test.wav"
	@echo "  make test_snare_asm    → snare_asm_test.wav"
	@echo "  make test_hat_asm      → hat_asm_test.wav"
	@echo "  make test_melody_asm   → melody_asm_test.wav"
	@echo "  make test_fm_asm       → fm_asm_test.wav"
	@echo ""
	@echo "Drum Combinations:"
	@echo "  make test_drums_asm    → drums_asm_test.wav (ASM kick+snare+hat)"
	@echo "  make test_drums_c      → drums_c_test.wav (C version reference)"
	@echo ""
	@echo "Voice Combinations:"
	@echo "  make test_drums_melody → drums_melody_test.wav"
	@echo "  make test_drums_fm     → drums_fm_test.wav"
	@echo "  make test_melody_fm    → melody_fm_test.wav"
	@echo ""
	@echo "Effects Testing:"
	@echo "  make test_no_effects   → no_effects_test.wav (voices only)"
	@echo "  make test_with_delay   → with_delay_test.wav"
	@echo "  make test_with_limiter → with_limiter_test.wav"
	@echo ""
	@echo "Complete Pipeline:"
	@echo "  make test_full_asm     → full_asm_test.wav (everything)"
	@echo ""
	@echo "Quick Suites:"
	@echo "  make test_all_voices   → generates all individual voice tests"

.PHONY: bells
bells: $(BELLS_BIN)
	$(BELLS_BIN)
	@echo "Generated bells-c.wav"

.PHONY: calm
calm: $(CALM_BIN)
	$(CALM_BIN)
	@echo "Generated calm-c.wav"

.PHONY: quantum
quantum: $(QUANTUM_BIN)
	$(QUANTUM_BIN)
	@echo "Generated quantum-c.wav"

.PHONY: pluck
pluck: $(PLUCK_BIN)
	$(PLUCK_BIN)
	@echo "Generated pluck-c.wav"

.PHONY: bass
bass: $(BASS_BIN)
	$(BASS_BIN)
	@echo "Generated bass_only.wav"

.PHONY: realtime
realtime: $(REALTIME_BIN)

.PHONY: clang_check
clang_check:
	@clang -v >/dev/null 2>&1 && echo "clang OK" || echo "clang missing"

.PHONY: clean-asm
clean-asm:
	rm -f $(ASM_OBJ)

.PHONY: bass_quantum
bass_quantum: $(BASSQ_BIN)
	$(BASSQ_BIN)
	@echo "Generated bass_quantum.wav"

.PHONY: bass_plucky
bass_plucky: $(BASSP_BIN)
	$(BASSP_BIN)
	@echo "Generated bass_plucky.wav"

# Convenience target: build everything for arm64 on x86 hosts
.PHONY: cross
cross:
	$(MAKE) clean
	$(MAKE) all CROSS=1 -j$(shell sysctl -n hw.logicalcpu)