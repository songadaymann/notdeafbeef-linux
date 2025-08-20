
# NotDeafbeef - Root Build System
# Orchestrates builds for both C and Assembly implementations

# Default target builds the stable configuration
all: c-build

# Build C implementation (stable)
c-build:
	$(MAKE) -C src/c

# Export timeline JSON for a given seed (usage: make export_timeline SEED=0xDEADBEEF OUT=path.json)
export_timeline:
	$(MAKE) -C src/c bin/export_timeline
	cd src/c && ./bin/export_timeline $(SEED) $(OUT)

# Visual assembly object files
visual_core.o: asm/visual/visual_core.s
	gcc -c asm/visual/visual_core.s -o visual_core.o

drawing.o: asm/visual/drawing.s
	gcc -c asm/visual/drawing.s -o drawing.o

ascii_renderer.o: asm/visual/ascii_renderer.s
	gcc -c asm/visual/ascii_renderer.s -o ascii_renderer.o

particles.o: asm/visual/particles.s
	gcc -c asm/visual/particles.s -o particles.o

bass_hits.o: asm/visual/bass_hits.s
	gcc -c asm/visual/bass_hits.s -o bass_hits.o

terrain.o: asm/visual/terrain.s
	gcc -c asm/visual/terrain.s -o terrain.o

glitch_system.o: asm/visual/glitch_system.s
	gcc -c asm/visual/glitch_system.s -o glitch_system.o

# Build visual system with ASM components
vis-build: visual_core.o drawing.o ascii_renderer.o particles.o bass_hits.o terrain.o glitch_system.o
	mkdir -p bin
	gcc -o bin/vis_main src/vis_main.c src/visual_c_stubs.c src/audio_visual_bridge.c src/wav_reader.c visual_core.o drawing.o ascii_renderer.o particles.o bass_hits.o terrain.o glitch_system.o -Iinclude $(shell pkg-config --cflags --libs sdl2) -lm

# Frame generator (no SDL2 required)
generate_frames: visual_core.o drawing.o ascii_renderer.o particles.o bass_hits.o terrain.o glitch_system.o
	gcc -o generate_frames generate_frames.c src/audio_visual_bridge.c src/deterministic_prng.c src/timeline_reader.c simple_wav_reader.c visual_core.o drawing.o ascii_renderer.o particles.o bass_hits.o terrain.o glitch_system.o -Iinclude -Isrc/include -lm

# Build audio system only (for protection verification)
audio:
	$(MAKE) -C src/c segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM"

# Generate test audio files  
test-audio:
	python3 tools/generate_test_wavs.py

# NEW: Generate comprehensive WAV tests for all sounds in both C and ASM
test-comprehensive:
	python3 tools/generate_comprehensive_tests.py

# NEW: Compare C vs ASM WAV files
compare:
	python3 tools/compare_c_vs_asm.py

# NEW: Play specific sound for audition (usage: make play SOUND=kick)
play:
ifndef SOUND
	@echo "Usage: make play SOUND=<sound_name>"
	@echo "Example: make play SOUND=kick"
else
	python3 tools/compare_c_vs_asm.py --play $(SOUND)
endif

# Run test suite
test:
	pytest tests/

# Clean all build artifacts
clean:
	$(MAKE) -C src/c clean
	rm -rf output/
	find . -name "*.o" -delete
	find . -name "*.dSYM" -delete
	rm -f generate_frames 2>/dev/null || true

# Generate a demo audio segment
demo:
	$(MAKE) -C src/c segment
	@echo "Generated demo audio: src/c/seed_0xcafebabe.wav"

# Quick verification that everything works
verify: c-build test-audio
	@echo "✅ NotDeafbeef verification complete!"

# NEW: Full verification including comprehensive tests
verify-full: c-build test-comprehensive compare
	@echo "✅ NotDeafbeef full verification complete!"
	@echo "Check the comparison output above for any issues."

.PHONY: all c-build vis-build audio test-audio test-comprehensive compare play test clean demo verify verify-full
