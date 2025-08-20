
#!/bin/bash

# generate_nft.sh - NotDeafBeef NFT Generation Pipeline
# Generates complete audio-visual NFT from Ethereum transaction hash
# 
# Usage: ./generate_nft.sh <tx_hash> [output_dir]
# Example: ./generate_nft.sh 0xDEADBEEF123456789ABCDEF output/

set -e  # Exit on any error

# Configuration
TX_HASH=${1:-"0xDEADBEEF"}
OUTPUT_DIR=${2:-"./nft_output"}
SEED="$TX_HASH"  # Use full transaction hash as seed
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCRIPT_DIR=$(pwd)  # Store script directory for absolute paths

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate inputs
if [ -z "$TX_HASH" ]; then
    error "Transaction hash required. Usage: $0 <tx_hash> [output_dir]"
fi

# Create output directory structure
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/temp"

# File names
AUDIO_BASE="$OUTPUT_DIR/temp/${SEED}_base.wav"
AUDIO_LONG="$OUTPUT_DIR/${TX_HASH}_audio.wav"
VIDEO_FINAL="$OUTPUT_DIR/${TX_HASH}_final.mp4"
METADATA_FILE="$OUTPUT_DIR/${TX_HASH}_metadata.json"

log "🎨 Starting NFT generation for transaction: $TX_HASH"
log "   Seed: $SEED"
log "   Output: $OUTPUT_DIR"

# Step 1: Generate base audio segment
log "🎵 Step 1: Generating base audio segment..."
cd src/c

# Build if necessary
if [ ! -f bin/segment ]; then
    log "   Building audio engine..."
    make segment USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM FM_VOICE_ASM" || error "Failed to build audio engine"
fi

# Generate base segment
log "   Synthesizing audio with seed $SEED..."
./bin/segment "$SEED" > /dev/null 2>&1

# Find generated file
SEGMENT_FILE=$(ls seed_0x*.wav 2>/dev/null | head -1)
if [ ! -f "$SEGMENT_FILE" ]; then
    error "Audio generation failed - no output file found"
fi

# Move to our naming convention
mv "$SEGMENT_FILE" "../../$AUDIO_BASE"
cd ../..

AUDIO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$AUDIO_BASE" 2>/dev/null)
success "Generated base audio: ${AUDIO_DURATION}s"

# Step 2: Create extended audio (6x concatenation ≈ 25 seconds)
log "🔄 Step 2: Creating extended audio track..."

# Create temp directory for concatenation
TEMP_CONCAT="$OUTPUT_DIR/temp/concat"
mkdir -p "$TEMP_CONCAT"

# Create 6 copies for concatenation
for i in {1..6}; do
    cp "$AUDIO_BASE" "$TEMP_CONCAT/segment_$i.wav"
done

# Concatenate with sox (fallback to ffmpeg if sox not available)
if command -v sox >/dev/null 2>&1; then
    log "   Using sox for concatenation..."
    sox "$TEMP_CONCAT"/segment_*.wav "$AUDIO_LONG" 2>/dev/null || error "Sox concatenation failed"
else
    log "   Using ffmpeg for concatenation..."
    # Create file list for ffmpeg
    for i in {1..6}; do
        echo "file '$TEMP_CONCAT/segment_$i.wav'" >> "$TEMP_CONCAT/filelist.txt"
    done
    ffmpeg -f concat -safe 0 -i "$TEMP_CONCAT/filelist.txt" -c copy "$AUDIO_LONG" -y >/dev/null 2>&1 || error "FFmpeg concatenation failed"
fi

EXTENDED_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$AUDIO_LONG" 2>/dev/null)
success "Created extended audio: ${EXTENDED_DURATION}s"

# Step 3: Generate visual frames
log "🖼️  Step 3: Generating visual frames..."

# Build frame generator if needed
if [ ! -f generate_frames ]; then
    log "   Building frame generator..."
    make generate_frames || error "Failed to build frame generator"
fi

# Generate frames (change to output directory to ensure frames are created in the right place)
log "   Rendering frames with seed $SEED..."
AUDIO_LONG_ABS="$SCRIPT_DIR/$AUDIO_LONG"  # Convert to absolute path
cd "$OUTPUT_DIR"
"$SCRIPT_DIR/generate_frames" "$AUDIO_LONG_ABS" "$SEED" > "temp/frame_log.txt" 2>&1
cd "$SCRIPT_DIR"

# Check if frames were generated
FRAME_COUNT=$(ls "$OUTPUT_DIR"/frame_*.ppm 2>/dev/null | wc -l)
if [ "$FRAME_COUNT" -eq 0 ]; then
    error "Frame generation failed - no frames found"
fi

success "Generated $FRAME_COUNT frames"

# Step 4: Create final video (run from output directory where frames are)
log "🎬 Step 4: Creating final video..."
AUDIO_LONG_ABS="$SCRIPT_DIR/$AUDIO_LONG"  # Convert to absolute path
VIDEO_NAME="${TX_HASH}_final.mp4"  # Just the filename, not full path
cd "$OUTPUT_DIR"

ffmpeg -r 60 -i frame_%04d.ppm \
       -i "$AUDIO_LONG_ABS" \
       -c:v libx264 -c:a aac \
       -pix_fmt yuv420p \
       -shortest "$VIDEO_NAME" \
       -y || error "Video creation failed"

cd "$SCRIPT_DIR"

# Verify video was created
if [ ! -f "$VIDEO_FINAL" ]; then
    error "Video file was not created"
fi

VIDEO_SIZE=$(du -h "$VIDEO_FINAL" | cut -f1)
VIDEO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VIDEO_FINAL" 2>/dev/null)
success "Created final video: ${VIDEO_DURATION}s, $VIDEO_SIZE"

# Step 5: Generate metadata
log "📋 Step 5: Generating metadata..."

cat > "$METADATA_FILE" << EOF
{
  "transaction_hash": "$TX_HASH",
  "seed": "$SEED", 
  "audio_duration": $EXTENDED_DURATION,
  "video_duration": $VIDEO_DURATION,
  "video_size": "$VIDEO_SIZE",
  "video_resolution": "800x600",
  "frame_rate": 60,
  "frame_count": $FRAME_COUNT,
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "assembly_version": "v1.0",
  "reproducible": true,
  "files": {
    "video": "$(basename "$VIDEO_FINAL")",
    "audio": "$(basename "$AUDIO_LONG")", 
    "metadata": "$(basename "$METADATA_FILE")"
  }
}
EOF

success "Generated metadata"

# Step 6: Cleanup temporary files
log "🧹 Step 6: Cleaning up..."
rm -f frame_*.ppm
rm -rf "$OUTPUT_DIR/temp"

# Final summary
log "✨ NFT Generation Complete!"
echo ""
echo "📁 Generated Files:"
echo "   🎬 Video: $VIDEO_FINAL"
echo "   🎵 Audio: $AUDIO_LONG"  
echo "   📋 Metadata: $METADATA_FILE"
echo ""
echo "🔍 NFT Details:"
echo "   📝 Transaction: $TX_HASH"
echo "   🎲 Seed: $SEED"
echo "   ⏱️  Duration: ${VIDEO_DURATION}s"
echo "   📦 Size: $VIDEO_SIZE"
echo ""
echo "✅ Ready for NFT marketplace upload!"
echo ""

# Verification hint
echo "🔄 To verify reproducibility, run:"
echo "   ./verify_nft.sh $TX_HASH $VIDEO_FINAL"
