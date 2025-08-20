#!/bin/bash
# Test Linux ARM64 compatibility for NotDeafbeef
# This script validates that the build system works on Linux

set -e

echo "🐧 Testing Linux ARM64 Compatibility"
echo "===================================="
echo ""

# Show current platform
echo "Platform: $(uname -s) $(uname -m)"
echo ""

# Test 1: Check Makefile SDL detection
echo "🔧 Testing SDL detection..."
cd src/c
make clean >/dev/null 2>&1 || true

# Show what SDL flags would be used
echo "SDL_CFLAGS: $(pkg-config --cflags sdl2 2>/dev/null || echo 'NOT FOUND')"
echo "SDL_LIBS: $(pkg-config --libs sdl2 2>/dev/null || echo 'NOT FOUND')"
echo ""

# Test 2: Check if we can compile a simple audio object
echo "🎵 Testing audio system compilation..."
if make src/linuxaudio.o >/dev/null 2>&1; then
    echo "✅ Linux audio system compiles successfully"
else
    echo "❌ Linux audio system compilation failed"
fi

cd ../..

# Test 3: Check if we can build generate_frames (core functionality)
echo "🎨 Testing frame generation build..."
if make generate_frames >/dev/null 2>&1; then
    echo "✅ Frame generator builds successfully"
else
    echo "❌ Frame generator build failed"
    echo "Try installing missing dependencies:"
    echo "  Ubuntu: sudo apt install build-essential libsdl2-dev"
fi

echo ""
echo "🏁 Linux compatibility test complete"
