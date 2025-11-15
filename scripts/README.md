# Build Scripts

This directory contains scripts for building and releasing MultitrackRecorder.

## Scripts Overview

### `build_portaudio_universal.sh`

Builds PortAudio as a universal library (arm64 + x86_64) from source.

**Usage:**
```bash
./scripts/build_portaudio_universal.sh
```

**What it does:**
- Downloads PortAudio v19.7.0 source code
- Builds separately for arm64 and x86_64 architectures
- Combines into a universal binary using `lipo`
- Installs to `libs/portaudio/`

**Output:**
- `libs/portaudio/lib/libportaudio.a` - Universal static library
- `libs/portaudio/include/` - Header files

**Note:** This script is automatically called by other build scripts if the universal library doesn't exist.

---

### `build_local.sh`

Quick local build for development and testing.

**Usage:**
```bash
./scripts/build_local.sh
```

**What it does:**
- Builds universal PortAudio if needed
- Compiles the app as a universal binary (arm64 + x86_64)
- No code signing or notarization
- Fast builds for local testing

**Output:**
- `build/DerivedData/.../MultitrackRecorder.app`

---

### `build_release.sh`

Full release build with code signing and notarization.

**Usage:**
```bash
# Set environment variables first
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# Run the build
./scripts/build_release.sh
```

**What it does:**
- Builds universal PortAudio if needed
- Compiles the app as a universal binary
- Signs with Developer ID certificate
- Creates a DMG for distribution
- Notarizes with Apple (if credentials provided)
- Staples notarization ticket
- Generates SHA256 checksum

**Output:**
- `build/MultitrackRecorder.dmg` - Signed and notarized DMG
- `build/MultitrackRecorder.dmg.sha256` - Checksum file

**Required Environment Variables:**
- `CODE_SIGN_IDENTITY` - Your Developer ID certificate name
- `APPLE_TEAM_ID` - Your Apple Developer Team ID
- `APPLE_ID` - Your Apple ID email (for notarization)
- `APPLE_APP_SPECIFIC_PASSWORD` - App-specific password (for notarization)

See [SECRETS_SETUP.md](SECRETS_SETUP.md) for detailed setup instructions.

---

## Build Process Flow

### Local Development Build

```
./scripts/build_local.sh
    ↓
Check if libs/portaudio exists
    ↓ (if not found)
./scripts/build_portaudio_universal.sh
    ↓
Download PortAudio source
    ↓
Build for arm64
    ↓
Build for x86_64
    ↓
Create universal binary with lipo
    ↓
Install to libs/portaudio/
    ↓ (back to build_local.sh)
Build MultitrackRecorder app
    ↓
Output: build/DerivedData/.../MultitrackRecorder.app
```

### Release Build

```
./scripts/build_release.sh
    ↓
Build universal PortAudio (if needed)
    ↓
Build MultitrackRecorder app
    ↓
Verify universal binary
    ↓
Code sign with Developer ID
    ↓
Create DMG
    ↓
Sign DMG
    ↓
Submit to Apple for notarization
    ↓
Wait for notarization
    ↓
Staple notarization ticket
    ↓
Generate SHA256 checksum
    ↓
Output: build/MultitrackRecorder.dmg
```

## Why Universal PortAudio?

When building a universal binary (arm64 + x86_64), Xcode needs access to the PortAudio library and headers for both architectures. The Homebrew version of PortAudio on Apple Silicon only provides the arm64 version, which causes build failures when compiling for x86_64.

By building PortAudio from source as a universal library, we can:
- ✅ Build truly universal binaries that run natively on both Apple Silicon and Intel Macs
- ✅ Avoid dependency on Homebrew installation
- ✅ Ensure consistent library version across builds
- ✅ Simplify the build process for end users

## Troubleshooting

### PortAudio Build Fails

**Problem:** `build_portaudio_universal.sh` fails during compilation.

**Solutions:**
1. Ensure you have Xcode command line tools installed:
   ```bash
   xcode-select --install
   ```

2. Check that you have an internet connection (to download source)

3. Manually download and verify the PortAudio source

### Universal Binary Not Created

**Problem:** Build succeeds but verification fails.

**Solutions:**
1. Check the actual architectures:
   ```bash
   lipo -info build/DerivedData/Build/Products/Release/MultitrackRecorder.app/Contents/MacOS/MultitrackRecorder
   ```
   Expected output: `Architectures in the fat file: ... are: x86_64 arm64` (order may vary)

2. If only one architecture is present, check that both arm64 and x86_64 builds completed:
   ```bash
   # Clean and rebuild
   rm -rf build/
   ./scripts/build_local.sh
   ```

### Build Script Can't Find PortAudio

**Problem:** Build fails with "cannot find 'Pa_Initialize'" or similar errors.

**Solutions:**
1. Verify the universal library exists:
   ```bash
   ls -la libs/portaudio/lib/libportaudio.a
   lipo -info libs/portaudio/lib/libportaudio.a
   ```

2. Rebuild PortAudio:
   ```bash
   rm -rf libs/portaudio
   ./scripts/build_portaudio_universal.sh
   ```

### Code Signing Fails

**Problem:** Code signing errors during release build.

**Solutions:**
1. Verify your certificate is installed:
   ```bash
   security find-identity -v -p codesigning
   ```

2. Check that `CODE_SIGN_IDENTITY` matches your certificate name exactly

3. See [SECRETS_SETUP.md](SECRETS_SETUP.md) for certificate setup

## Clean Builds

To completely clean and rebuild:

```bash
# Remove all build artifacts
rm -rf build/

# Remove compiled PortAudio library
rm -rf libs/portaudio/

# Rebuild everything
./scripts/build_local.sh
# or
./scripts/build_release.sh
```

## Architecture Support

All builds create universal binaries with:
- **arm64**: Native support for Apple Silicon (M1, M2, M3, etc.)
- **x86_64**: Native support for Intel Macs

Users on either architecture can run the app natively without Rosetta translation.

## File Locations

```
multitrack-recorder-swift/
├── scripts/
│   ├── build_portaudio_universal.sh  # Build PortAudio from source
│   ├── build_local.sh                # Quick local builds
│   ├── build_release.sh              # Full release builds
│   ├── README.md                     # This file
│   └── SECRETS_SETUP.md              # GitHub secrets setup guide
├── libs/
│   └── portaudio/                    # Universal PortAudio library
│       ├── lib/
│       │   └── libportaudio.a        # Universal static library
│       └── include/
│           └── portaudio.h           # Header files
└── build/                            # Build output directory
    ├── MultitrackRecorder.dmg        # Release DMG
    └── DerivedData/                  # Xcode build products
```

## Additional Documentation

- [RELEASE.md](../RELEASE.md) - Complete release process guide
- [SECRETS_SETUP.md](SECRETS_SETUP.md) - GitHub secrets configuration
- [README.md](../README.md) - Main project documentation
