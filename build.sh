#!/bin/bash
# NotDeafbeef Reconstruction Build Script  
# ========================================
# This script is included in the on-chain source code.
# Users run this after downloading and extracting all chunks.

set -e

echo "🎵 NotDeafbeef - Building ARM64 Assembly Audio-Visual Engine"
echo "============================================================="
echo ""

# Check for ARM64 architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
    echo "⚠️  WARNING: This system requires ARM64 architecture"
    echo "   Current architecture: $ARCH"
    echo "   Required: arm64 (Apple Silicon) or aarch64 (ARM64 Linux)"
    echo ""
    echo "💡 Try running on:"
    echo "   - Apple Silicon Mac (M1/M2/M3)"
    echo "   - ARM64 Linux system"
    echo "   - ARM64 cloud instance"
    echo ""
    read -p "Continue anyway? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for required tools
echo "🔧 Checking build dependencies..."

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1 found"
    else
        echo "❌ $1 not found - please install"
        return 1
    fi
}

MISSING_TOOLS=0
check_tool gcc || MISSING_TOOLS=1
check_tool make || MISSING_TOOLS=1 
check_tool ffmpeg || MISSING_TOOLS=1

if [[ $MISSING_TOOLS -eq 1 ]]; then
    echo ""
    echo "📦 Installation commands:"
    echo "  macOS:   brew install ffmpeg"
    echo "  Ubuntu:  sudo apt install build-essential ffmpeg"
    exit 1
fi

echo ""

# Check if seed has been set
if grep -q "PASTE_YOUR_TOKEN_SEED_HERE" seed.s; then
    echo "🚨 SEED NOT SET!"
    echo ""
    echo "❌ You must replace the seed placeholder in seed.s"
    echo ""
    echo "📋 Instructions:"
    echo "   1. Get your seed: call getTokenParams(tokenId) on the contract"
    echo "   2. Edit seed.s file"
    echo "   3. Replace 'PASTE_YOUR_TOKEN_SEED_HERE' with your 64-char hex seed"
    echo "   4. Keep the quotes and 0x prefix"
    echo "   5. Run this script again"
    echo ""
    echo "💡 Example:"
    echo '   SEED_HEX: .ascii "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\0"'
    exit 1
fi

# Extract the seed for use in generation
SEED=$(grep 'SEED_HEX:' seed.s | sed 's/.*"\(0x[^"]*\)".*/\1/' | tr -d '\n')
echo "🎯 Using seed: $SEED"
echo ""

# Build the audio-visual engine
echo "🔨 Building ARM64 assembly components..."
echo ""

# Build audio engine
echo "🎵 Building audio synthesis engine..."
make -C src/c segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM FM_VOICE_ASM"

# Build visual engine  
echo "🎨 Building visual rendering engine..."
make generate_frames

echo ""
echo "✅ Build complete!"
echo ""

# Generate the NFT
echo "🚀 Generating your unique audio-visual NFT..."
echo "   This may take 2-5 minutes depending on your system..."
echo ""

OUTPUT_DIR="./nft_output"
mkdir -p "$OUTPUT_DIR"

# Generate audio and frames
./generate_nft.sh "$SEED" "$OUTPUT_DIR"

echo ""
echo "🔧 Finalizing NFT creation..."

# Normalize filename (handle complex seed-based names)
echo "   Cleaning up file names..."
if ls "$OUTPUT_DIR"/*_audio.wav 1> /dev/null 2>&1; then
    mv "$OUTPUT_DIR"/*_audio.wav "$OUTPUT_DIR/nft_audio.wav"
    echo "   ✅ Audio ready: nft_audio.wav"
else
    echo "   ❌ Audio file not found!"
    exit 1
fi

# Count frames
FRAME_COUNT=$(ls "$OUTPUT_DIR"/frame_*.ppm 2>/dev/null | wc -l | tr -d ' ')
echo "   ✅ Frames ready: $FRAME_COUNT frames"

# Create video with simple FFmpeg command
echo "   🎬 Encoding final video..."
cd "$OUTPUT_DIR"

ffmpeg -y \
    -r 60 \
    -i frame_%04d.ppm \
    -i nft_audio.wav \
    -c:v libx264 \
    -c:a aac \
    -pix_fmt yuv420p \
    -shortest \
    nft_final.mp4 \
    -v quiet 2>&1

cd ..

# Check result
if [[ -f "$OUTPUT_DIR/nft_final.mp4" ]]; then
    VIDEO_SIZE=$(ls -lh "$OUTPUT_DIR/nft_final.mp4" | awk '{print $5}')
    AUDIO_SIZE=$(ls -lh "$OUTPUT_DIR/nft_audio.wav" | awk '{print $5}')
    VIDEO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT_DIR/nft_final.mp4" 2>/dev/null | cut -d. -f1)
    
    echo ""
    echo "🎉 NFT Generation Complete!"
    echo "================================"
    echo ""
    echo "📁 Your NotDeafbeef NFT:"
    echo "🎬 Video: $OUTPUT_DIR/nft_final.mp4 ($VIDEO_SIZE, ${VIDEO_DURATION}s)"
    echo "🎵 Audio: $OUTPUT_DIR/nft_audio.wav ($AUDIO_SIZE)"
    echo "🎯 Seed: $SEED"
    echo ""
    echo "✨ Your NFT has been reconstructed from pure on-chain code!"
    echo "   Share nft_final.mp4 - others can verify by running this same process."
    echo ""
    echo "🔗 Verification:"
    echo "   Same seed + same code = identical output (cryptographically verifiable)"
    echo "   Your artwork is mathematically unique and permanently reproducible."
else
    echo "   ❌ Video creation failed"
    echo "   Check that ffmpeg is working and frames were generated correctly"
    exit 1
fi
