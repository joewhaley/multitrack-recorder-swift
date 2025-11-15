# Universal Build Setup - Summary

This document summarizes the changes made to enable universal binary builds (arm64 + x86_64) for MultitrackRecorder.

## Problem

When building for both Apple Silicon (arm64) and Intel (x86_64) architectures, the build failed because:
1. PortAudio installed via Homebrew on Apple Silicon only provides arm64 binaries
2. The x86_64 build couldn't find PortAudio headers and libraries
3. Cross-compilation for universal binaries requires libraries for both architectures

## Solution

We've implemented a solution that builds PortAudio as a universal library from source and embeds it in the project.

### Changes Made

#### 1. Universal PortAudio Library Build Script

**File:** `scripts/build_portaudio_universal.sh`

This script:
- Downloads PortAudio v19.7.0 source code
- Builds separately for arm64 and x86_64 architectures
- Combines both into a universal binary using `lipo`
- Installs to `libs/portaudio/` in the project directory

**Usage:**
```bash
./scripts/build_portaudio_universal.sh
```

#### 2. Updated Build Scripts

**Files:** `scripts/build_local.sh`, `scripts/build_release.sh`

Both scripts now:
- Automatically check if the universal PortAudio library exists
- Build it if missing (first-time setup)
- Build the app as a universal binary for both architectures

#### 3. Xcode Project Configuration

**File:** `MultitrackRecorder.xcodeproj/project.pbxproj`

Updated build settings:
- **Header Search Paths:** `$(PROJECT_DIR)/libs/portaudio/include`
- **Library Search Paths:** `$(PROJECT_DIR)/libs/portaudio/lib`
- **Other Linker Flags:** Added required frameworks (CoreAudio, AudioToolbox, AudioUnit, CoreServices)
- **Bridging Header:** Configured for both Debug and Release configurations

#### 4. GitHub Actions Workflow

**File:** `.github/workflows/release.yml`

Updated to build universal PortAudio before building the app (removed Homebrew dependency).

#### 5. Documentation

Created comprehensive documentation:
- `scripts/README.md` - Build scripts overview and troubleshooting
- `RELEASE.md` - Complete release process guide
- `scripts/SECRETS_SETUP.md` - GitHub secrets configuration guide

### File Structure

```
multitrack-recorder-swift/
├── libs/
│   └── portaudio/                     # Universal PortAudio library (generated)
│       ├── lib/
│       │   └── libportaudio.a         # Universal static library (arm64 + x86_64)
│       └── include/
│           └── portaudio.h            # Header files
├── scripts/
│   ├── build_portaudio_universal.sh   # Build universal PortAudio
│   ├── build_local.sh                 # Quick local builds
│   ├── build_release.sh               # Full release builds with signing
│   ├── README.md                      # Scripts documentation
│   └── SECRETS_SETUP.md               # GitHub secrets setup guide
├── .github/workflows/
│   └── release.yml                    # Automated release workflow
├── RELEASE.md                         # Release process documentation
└── UNIVERSAL_BUILD_SETUP.md           # This file
```

## How to Build

### First-Time Setup

The first time you build, the universal PortAudio library will be built automatically:

```bash
./scripts/build_local.sh
```

This will:
1. Download PortAudio source (~5 minutes)
2. Build for arm64 and x86_64
3. Create universal library in `libs/portaudio/`
4. Build MultitrackRecorder as universal binary

### Subsequent Builds

After the first build, the PortAudio library is cached and builds are much faster:

```bash
# Quick local build (no signing/notarization)
./scripts/build_local.sh

# Full release build (with signing/notarization)
./scripts/build_release.sh
```

### Clean Rebuild

To rebuild everything from scratch:

```bash
# Remove all build artifacts
rm -rf build/

# Remove cached PortAudio library
rm -rf libs/portaudio/

# Rebuild
./scripts/build_local.sh
```

## Verification

To verify a universal binary was created:

```bash
# Check the app binary
lipo -info build/DerivedData/Build/Products/Release/MultitrackRecorder.app/Contents/MacOS/MultitrackRecorder

# Expected output:
# Architectures in the fat file: ... are: x86_64 arm64
```

## Benefits

### ✅ Universal Binary Support
- Single app runs natively on both Apple Silicon and Intel Macs
- No Rosetta translation needed
- Optimal performance on both architectures

### ✅ Self-Contained Builds
- No dependency on Homebrew installation
- Consistent PortAudio version across all builds
- Reproducible builds

### ✅ Simplified Distribution
- One DMG works for all Mac users
- No architecture-specific builds needed
- GitHub Actions automatically builds universal binaries

### ✅ Developer Experience
- Automatic first-time setup
- Fast incremental builds
- Clear error messages and documentation

## Troubleshooting

### Build Fails - PortAudio Not Found

If you see errors like "cannot find 'Pa_Initialize'":

```bash
# Rebuild PortAudio library
rm -rf libs/portaudio
./scripts/build_portaudio_universal.sh
```

### Xcode Command Line Tools Missing

If PortAudio build fails:

```bash
xcode-select --install
```

### Architecture Verification Failed

If `lipo -info` doesn't show both architectures:

```bash
# Check the PortAudio library
lipo -info libs/portaudio/lib/libportaudio.a

# Should output: Architectures in the fat file: ... are: x86_64 arm64
```

### Clean Build Required

If you encounter unexpected build errors:

```bash
# Clean everything and rebuild
rm -rf build/ libs/portaudio/
./scripts/build_local.sh
```

## Dependencies

### Build Time
- **Xcode** 15.0 or later
- **Xcode Command Line Tools**
- **Internet connection** (for first-time PortAudio download)

### Runtime
- **macOS** 14.0 or later
- No external dependencies (PortAudio is statically linked)

## Technical Details

### PortAudio Build Configuration
- **Version:** 19.7.0
- **Type:** Static library (`.a`)
- **Architectures:** arm64, x86_64
- **macOS Deployment Target:** 14.0
- **Frameworks:** CoreAudio, AudioToolbox, AudioUnit, CoreServices

### Build Flags
```
arm64:  -arch arm64 -mmacosx-version-min=14.0
x86_64: -arch x86_64 -mmacosx-version-min=14.0
```

### Library Location
The universal library is stored in the project directory (`libs/portaudio/`) rather than a system location. This ensures:
- No conflicts with system-installed PortAudio
- Version consistency across developers
- Easier CI/CD integration

## Migration from Homebrew

If you previously used Homebrew's PortAudio:

1. **No action needed** - The new build system uses the local universal library automatically
2. **Optional:** You can uninstall Homebrew's PortAudio if not used by other projects:
   ```bash
   brew uninstall portaudio
   ```

## Git Ignore

The `libs/portaudio/` directory is **NOT** ignored by git (commented out in `.gitignore`). This allows:
- Faster builds for contributors (no need to build PortAudio)
- Consistent library version across all developers
- Smaller repository size (only ~320KB for the universal library)

If you prefer to build PortAudio locally instead of committing it:
1. Uncomment `# libs/` in `.gitignore`
2. Add `libs/` to `.gitignore`
3. First-time contributors will automatically build PortAudio

## Next Steps

- **Local Development:** Use `./scripts/build_local.sh` for testing
- **Release Builds:** Follow the guide in `RELEASE.md`
- **GitHub Actions:** Configure secrets using `scripts/SECRETS_SETUP.md`
- **Troubleshooting:** See `scripts/README.md` for common issues

## Success Criteria

✅ Build succeeds for both arm64 and x86_64
✅ Single app binary contains both architectures
✅ No external dependencies required at runtime
✅ Automated builds work on GitHub Actions
✅ DMG can be distributed to all Mac users

---

**Last Updated:** 2025-11-15
**PortAudio Version:** 19.7.0
**macOS Deployment Target:** 14.0
