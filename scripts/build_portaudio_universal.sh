#!/bin/bash

# Script to build PortAudio as a universal library (arm64 + x86_64)
# This is needed for creating universal macOS app bundles

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
PORTAUDIO_VERSION="19.7.0"
PORTAUDIO_URL="https://files.portaudio.com/archives/pa_stable_v190700_20210406.tgz"
BUILD_DIR="$(pwd)/build/portaudio"
INSTALL_DIR="$(pwd)/libs/portaudio"

log_info "Building universal PortAudio library..."
log_info "Version: $PORTAUDIO_VERSION"

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download PortAudio source
log_info "Downloading PortAudio source..."
curl -L -o portaudio.tgz "$PORTAUDIO_URL"
tar xzf portaudio.tgz
cd portaudio

# Build for arm64
log_info "Building for arm64..."
mkdir -p build-arm64
cd build-arm64
CFLAGS="-arch arm64 -mmacosx-version-min=14.0" \
LDFLAGS="-arch arm64" \
../configure \
    --prefix="$BUILD_DIR/install-arm64" \
    --disable-mac-universal \
    --enable-static \
    --disable-shared
make clean
make -j$(sysctl -n hw.ncpu)
make install
cd ..

# Build for x86_64
log_info "Building for x86_64..."
mkdir -p build-x86_64
cd build-x86_64
CFLAGS="-arch x86_64 -mmacosx-version-min=14.0" \
LDFLAGS="-arch x86_64" \
../configure \
    --prefix="$BUILD_DIR/install-x86_64" \
    --disable-mac-universal \
    --enable-static \
    --disable-shared
make clean
make -j$(sysctl -n hw.ncpu)
make install
cd ..

# Create universal binary using lipo
log_info "Creating universal binary..."
mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/include"

lipo -create \
    "$BUILD_DIR/install-arm64/lib/libportaudio.a" \
    "$BUILD_DIR/install-x86_64/lib/libportaudio.a" \
    -output "$INSTALL_DIR/lib/libportaudio.a"

# Copy headers (they should be the same for both architectures)
cp -R "$BUILD_DIR/install-arm64/include/"* "$INSTALL_DIR/include/"

# Verify universal binary
log_info "Verifying universal binary..."
lipo -info "$INSTALL_DIR/lib/libportaudio.a"

log_info "✅ Universal PortAudio library created successfully!"
log_info "Location: $INSTALL_DIR"
log_info ""
log_info "Library: $INSTALL_DIR/lib/libportaudio.a"
log_info "Headers: $INSTALL_DIR/include/"

# Clean up build directory (optional)
log_info "Cleaning up build files..."
cd "$(pwd)"
rm -rf "$BUILD_DIR"

log_info "Done! 🎉"
