#!/bin/bash

# Build script for creating signed macOS releases
# This script builds, signs, and creates a distributable DMG for MultitrackRecorder

set -e  # Exit on any error

# Configuration
APP_NAME="MultitrackRecorder"
BUNDLE_ID="com.multitrack.recorder"
SCHEME="MultitrackRecorder"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
DMG_DIR="$BUILD_DIR/DMG"
FINAL_DMG="$BUILD_DIR/$APP_NAME.dmg"

# Code signing identity - can be overridden via environment variable
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"

# Notarization credentials - must be set via environment variables
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Clean previous builds
log_info "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

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

# Build the app as a universal binary (arm64 + x86_64)
log_info "Building $APP_NAME as universal binary (arm64 + x86_64)..."
xcodebuild clean archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -arch arm64 -arch x86_64 \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    ONLY_ACTIVE_ARCH=NO

# Create export options plist with team ID
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
sed "s/TEAM_ID_PLACEHOLDER/$APPLE_TEAM_ID/g" ExportOptions.plist > "$EXPORT_OPTIONS"

# Export the archive
log_info "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# Locate the built app
BUILT_APP=$(find "$EXPORT_PATH" -name "$APP_NAME.app" -type d | head -1)

# Fallback to archive if export didn't work
if [ ! -d "$BUILT_APP" ]; then
    BUILT_APP=$(find "$ARCHIVE_PATH" -name "$APP_NAME.app" -type d | head -1)
fi

if [ ! -d "$BUILT_APP" ]; then
    log_error "Failed to find built app at expected location"
    exit 1
fi

log_info "App built at: $BUILT_APP"

# Verify universal binary
log_info "Verifying universal binary..."
EXECUTABLE="$BUILT_APP/Contents/MacOS/$APP_NAME"
LIPO_OUTPUT=$(lipo -info "$EXECUTABLE")
if echo "$LIPO_OUTPUT" | grep -q "arm64" && echo "$LIPO_OUTPUT" | grep -q "x86_64"; then
    log_info "✅ Confirmed universal binary (arm64 + x86_64)"
    echo "$LIPO_OUTPUT"
else
    log_error "Failed to create universal binary"
    echo "$LIPO_OUTPUT"
    exit 1
fi

# Re-sign with hardened runtime and timestamp (ensure proper signing)
log_info "Signing app with hardened runtime..."
codesign --force --sign "$SIGNING_IDENTITY" \
    --timestamp \
    --options runtime \
    --entitlements "MultitrackRecorder/MultitrackRecorder.entitlements" \
    --deep "$BUILT_APP"

# Verify code signature
log_info "Verifying code signature..."
codesign -vvv --deep --strict "$BUILT_APP"

# Verify hardened runtime
log_info "Verifying hardened runtime..."
codesign -d --entitlements - "$BUILT_APP"

# Check if notarization should be performed
NOTARIZE=false
if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_APP_SPECIFIC_PASSWORD" ]; then
    NOTARIZE=true
    log_info "Notarization credentials found - will notarize the app"
else
    log_warn "Notarization credentials not set - skipping notarization"
    log_warn "Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD to enable notarization"
fi

# Create DMG
log_info "Creating DMG..."
mkdir -p "$DMG_DIR"
cp -R "$BUILT_APP" "$DMG_DIR/"

# Create a symbolic link to Applications folder
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$FINAL_DMG"

log_info "DMG created at: $FINAL_DMG"

# Sign the DMG
log_info "Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$FINAL_DMG"

# Verify DMG signature
log_info "Verifying DMG signature..."
codesign -vvv --deep --strict "$FINAL_DMG"

# Notarize if credentials are available
if [ "$NOTARIZE" = true ]; then
    log_info "Submitting DMG for notarization..."

    # Submit for notarization
    NOTARIZE_OUTPUT=$(xcrun notarytool submit "$FINAL_DMG" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait)

    echo "$NOTARIZE_OUTPUT"

    # Check if notarization succeeded
    if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
        log_info "Notarization successful!"

        # Staple the notarization ticket
        log_info "Stapling notarization ticket..."
        xcrun stapler staple "$FINAL_DMG"

        log_info "✅ Build, signing, and notarization complete!"
    else
        log_error "Notarization failed."

        # Extract submission ID from output
        SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')

        if [ -n "$SUBMISSION_ID" ]; then
            log_info "Fetching detailed notarization log..."
            xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$APPLE_ID" \
                --team-id "$APPLE_TEAM_ID" \
                --password "$APPLE_APP_SPECIFIC_PASSWORD" 2>&1 | head -100
        fi

        exit 1
    fi
else
    log_info "✅ Build and signing complete (notarization skipped)!"
fi

# Display final artifact info
log_info "Final DMG: $FINAL_DMG"
log_info "Size: $(du -h "$FINAL_DMG" | cut -f1)"

# Create a checksum
log_info "Creating SHA256 checksum..."
shasum -a 256 "$FINAL_DMG" > "$FINAL_DMG.sha256"
log_info "Checksum saved to: $FINAL_DMG.sha256"

log_info "Build complete! 🎉"
