#!/bin/bash

# Quick local build script for development testing
# This builds the app without notarization or DMG creation

set -e

APP_NAME="MultitrackRecorder"
SCHEME="MultitrackRecorder"
CONFIGURATION="Release"
BUILD_DIR="build"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_info "Building $APP_NAME (local development build)..."

# Check if universal PortAudio library exists, build it if not
PORTAUDIO_LIB="$(pwd)/libs/portaudio/lib/libportaudio.a"
if [ ! -f "$PORTAUDIO_LIB" ]; then
    log_info "Universal PortAudio library not found. Building it now..."
    ./scripts/build_portaudio_universal.sh
else
    log_info "Using existing universal PortAudio library"
fi

# Set paths to local PortAudio
PORTAUDIO_LIB_DIR="$(pwd)/libs/portaudio/lib"
PORTAUDIO_INCLUDE_DIR="$(pwd)/libs/portaudio/include"

# Clean and build
xcodebuild clean build \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -arch arm64 -arch x86_64 \
    ONLY_ACTIVE_ARCH=NO

# Locate the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Failed to find built app"
    exit 1
fi

log_info "✅ Build complete!"
log_info "App location: $BUILT_APP"

# Verify universal binary
log_info "Verifying universal binary..."
EXECUTABLE="$BUILT_APP/Contents/MacOS/$APP_NAME"
LIPO_OUTPUT=$(lipo -info "$EXECUTABLE")
if echo "$LIPO_OUTPUT" | grep -q "arm64" && echo "$LIPO_OUTPUT" | grep -q "x86_64"; then
    log_info "✅ Confirmed universal binary (arm64 + x86_64)"
    echo "$LIPO_OUTPUT"
else
    log_info "⚠️  Single architecture build"
    echo "$LIPO_OUTPUT"
fi

log_info ""
log_info "To run the app:"
log_info "  open \"$BUILT_APP\""
