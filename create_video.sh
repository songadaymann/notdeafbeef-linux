
#!/bin/bash
# Simple FFmpeg wrapper for blockchain context
# Creates video from existing frames + audio

set -e

OUTPUT_DIR="./nft_output"

echo "🎬 Creating video from generated frames and audio..."
echo "   Working directory: $(pwd)"

# Find the actual audio file (handle weird filenames)
AUDIO_FILE=$(ls $OUTPUT_DIR/*_audio.wav | head -1)
if [[ ! -f "$AUDIO_FILE" ]]; then
    echo "❌ No audio file found in $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR/"
    exit 1
fi

# Extract seed from filename for video name
BASENAME=$(basename "$AUDIO_FILE" "_audio.wav")
echo "   Audio file: $AUDIO_FILE"
echo "   Basename: $BASENAME"

# Count frames
FRAME_COUNT=$(ls $OUTPUT_DIR/frame_*.ppm | wc -l | tr -d ' ')
echo "   Found $FRAME_COUNT frames"
echo "   Audio: $(ls -lh "$AUDIO_FILE" | awk '{print $5}')"

# Output video  
VIDEO_FILE="$OUTPUT_DIR/${BASENAME}_final.mp4"

echo ""
echo "🔧 Running FFmpeg..."
echo "   Output: $VIDEO_FILE"

# Use absolute paths and run from frames directory
cd "$OUTPUT_DIR"

# Get just the audio filename (not full path)
AUDIO_NAME=$(basename "$AUDIO_FILE")

# Simple, explicit FFmpeg command with verbose output for debugging
echo "   Command: ffmpeg -r 60 -i frame_%04d.ppm -i $AUDIO_NAME -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest ${BASENAME}_final.mp4"

ffmpeg -y \
    -r 60 \
    -i frame_%04d.ppm \
    -i "$AUDIO_NAME" \
    -c:v libx264 \
    -c:a aac \
    -pix_fmt yuv420p \
    -shortest \
    "${BASENAME}_final.mp4" 2>&1

cd ..

# Check result
if [[ -f "$VIDEO_FILE" ]]; then
    VIDEO_SIZE=$(ls -lh "$VIDEO_FILE" | awk '{print $5}')
    VIDEO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d. -f1)
    echo ""
    echo "✅ Video created successfully!"
    echo "   File: ${VIDEO_FILE}"
    echo "   Size: $VIDEO_SIZE"
    echo "   Duration: ${VIDEO_DURATION}s"
    echo ""
    echo "🎉 Your NotDeafbeef NFT is complete!"
else
    echo "❌ Video creation failed"
    exit 1
fi
