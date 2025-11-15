# Release Workflow Overview

This document explains how the release system works for both local and GitHub Actions builds.

## Local Build Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ Local Developer Machine                                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Set environment variables (from publish.sh)             │
│     ├─ APPLE_ID                                              │
│     ├─ APPLE_TEAM_ID                                         │
│     ├─ CODE_SIGN_IDENTITY                                    │
│     └─ APPLE_APP_SPECIFIC_PASSWORD                           │
│                                                               │
│  2. Run: ./scripts/build_release.sh                          │
│     │                                                         │
│     ├─ Check for universal PortAudio library                 │
│     │   └─ Build if missing (first time only)                │
│     │                                                         │
│     ├─ Build app as universal binary (arm64 + x86_64)        │
│     │   ├─ Archive with xcodebuild                           │
│     │   └─ Export with hardened runtime                      │
│     │                                                         │
│     ├─ Sign app with Developer ID                            │
│     │   ├─ Hardened runtime: ✓                               │
│     │   ├─ Timestamp: ✓                                      │
│     │   └─ No debug entitlements: ✓                          │
│     │                                                         │
│     ├─ Create DMG                                            │
│     │   ├─ Copy app to temporary directory                   │
│     │   ├─ Add Applications symlink                          │
│     │   └─ Create disk image                                 │
│     │                                                         │
│     ├─ Sign DMG                                              │
│     │   └─ With timestamp                                    │
│     │                                                         │
│     ├─ Submit to Apple Notary Service                        │
│     │   ├─ Upload DMG                                        │
│     │   ├─ Wait for processing                               │
│     │   └─ Check status (Accepted/Invalid)                   │
│     │                                                         │
│     ├─ Staple notarization ticket                            │
│     │   └─ Embed ticket in DMG                               │
│     │                                                         │
│     └─ Generate SHA256 checksum                              │
│                                                               │
│  3. Output:                                                  │
│     ├─ build/MultitrackRecorder.dmg (signed & notarized)     │
│     └─ build/MultitrackRecorder.dmg.sha256                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## GitHub Actions Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ Trigger: git tag v1.0.0 && git push origin v1.0.0          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions Runner (macOS)                                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Checkout code                                            │
│                                                               │
│  2. Set up Xcode                                             │
│                                                               │
│  3. Build universal PortAudio library                        │
│     └─ ./scripts/build_portaudio_universal.sh                │
│                                                               │
│  4. Import code signing certificate                          │
│     ├─ Decode BUILD_CERTIFICATE_BASE64 secret                │
│     ├─ Create temporary keychain                             │
│     ├─ Import certificate with P12_PASSWORD                  │
│     └─ Configure keychain for codesign access                │
│                                                               │
│  5. Build, sign, and notarize                                │
│     ├─ Set environment from GitHub Secrets:                  │
│     │   ├─ CODE_SIGN_IDENTITY                                │
│     │   ├─ APPLE_ID                                          │
│     │   ├─ APPLE_TEAM_ID                                     │
│     │   └─ APPLE_APP_SPECIFIC_PASSWORD                       │
│     │                                                         │
│     └─ Run: ./scripts/build_release.sh                       │
│         (same process as local build)                        │
│                                                               │
│  6. Create GitHub Release                                    │
│     ├─ Extract version from tag (v1.0.0 → 1.0.0)             │
│     ├─ Create release with description                       │
│     └─ Upload assets:                                        │
│         ├─ MultitrackRecorder-1.0.0.dmg                      │
│         └─ MultitrackRecorder-1.0.0.dmg.sha256               │
│                                                               │
│  7. Clean up                                                 │
│     └─ Delete temporary keychain                             │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ GitHub Release Published                                     │
│ https://github.com/user/repo/releases/tag/v1.0.0            │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables vs GitHub Secrets

### Local Development (publish.sh)

```bash
# These are set in publish.sh (NOT committed to git)
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (YOUR_TEAM_ID)"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### GitHub Actions (Repository Secrets)

These same values are stored as **encrypted secrets** in GitHub:

| Local Variable | GitHub Secret | Where It's Used |
|----------------|---------------|-----------------|
| `APPLE_ID` | `secrets.APPLE_ID` | Notarization |
| `APPLE_TEAM_ID` | `secrets.APPLE_TEAM_ID` | Code signing & notarization |
| `CODE_SIGN_IDENTITY` | `secrets.CODE_SIGN_IDENTITY` | Code signing |
| `APPLE_APP_SPECIFIC_PASSWORD` | `secrets.APPLE_APP_SPECIFIC_PASSWORD` | Notarization |
| *Certificate file* | `secrets.BUILD_CERTIFICATE_BASE64` | Code signing (base64 encoded) |
| *Certificate password* | `secrets.P12_PASSWORD` | Importing certificate |
| *Random string* | `secrets.KEYCHAIN_PASSWORD` | Temporary keychain |

## Setup Steps

### For Local Builds

1. **One-time setup:**
   ```bash
   # Copy example and add your credentials
   cp publish.sh.example publish.sh
   # Edit publish.sh with your values
   ```

2. **Build and release:**
   ```bash
   source publish.sh  # or ./publish.sh
   ```

### For GitHub Actions

1. **One-time setup:** Configure GitHub Secrets
   - See: [GITHUB_SECRETS_SETUP.md](GITHUB_SECRETS_SETUP.md)

2. **Create releases:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

## Security

### ✅ Secure Practices

- **Local:** Credentials in `publish.sh` (ignored by git)
- **GitHub:** Encrypted secrets (never exposed in logs)
- **Certificates:** Only imported to temporary keychain
- **App-specific passwords:** Not your main Apple ID password

### ❌ Never Do This

- Commit `publish.sh` with real credentials
- Use your main Apple ID password
- Share secrets in issues/PRs
- Hardcode credentials in scripts

## File Locations

```
multitrack-recorder-swift/
├── publish.sh                    # Local credentials (NOT in git)
├── publish.sh.example            # Template for publish.sh
├── scripts/
│   ├── build_release.sh          # Main release build script
│   ├── build_local.sh            # Quick local builds
│   └── build_portaudio_universal.sh  # Build PortAudio
├── .github/workflows/
│   └── release.yml               # GitHub Actions workflow
├── GITHUB_SECRETS_SETUP.md       # Quick secrets setup guide
├── RELEASE.md                    # Detailed release documentation
└── RELEASE_WORKFLOW.md           # This file
```

## Troubleshooting

### Local Build Issues

1. **Missing credentials:**
   ```bash
   # Ensure all variables are set
   env | grep -E "APPLE_|CODE_SIGN"
   ```

2. **Notarization fails:**
   ```bash
   # Check detailed log (get ID from error output)
   xcrun notarytool log SUBMISSION_ID \
     --apple-id "$APPLE_ID" \
     --team-id "$APPLE_TEAM_ID" \
     --password "$APPLE_APP_SPECIFIC_PASSWORD"
   ```

### GitHub Actions Issues

1. **Check secrets are configured:**
   - Go to Settings → Secrets and variables → Actions
   - Verify all 7 secrets are present

2. **View workflow logs:**
   - Go to Actions tab in your repository
   - Click on the failed workflow run
   - Expand each step to see detailed logs

3. **Common errors:**
   - **"Invalid certificate"** → `BUILD_CERTIFICATE_BASE64` or `P12_PASSWORD` is wrong
   - **"Invalid credentials"** → `APPLE_ID`, `APPLE_TEAM_ID`, or `APPLE_APP_SPECIFIC_PASSWORD` is wrong
   - **"Build failed"** → Check Xcode version or PortAudio build

## Quick Reference

### Create a Release

**Local:**
```bash
source publish.sh
```

**GitHub Actions:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Verify a Build

```bash
# Check universal binary
lipo -info build/Export/MultitrackRecorder.app/Contents/MacOS/MultitrackRecorder

# Check code signing
codesign -dvvv build/Export/MultitrackRecorder.app

# Check notarization
spctl -a -vvv -t install build/Export/MultitrackRecorder.app

# Check DMG signature
codesign -dvvv build/MultitrackRecorder.dmg
```

### Update Credentials

**Local:** Edit `publish.sh`

**GitHub:** Settings → Secrets → Update secret

---

**See Also:**
- [GITHUB_SECRETS_SETUP.md](GITHUB_SECRETS_SETUP.md) - Quick secrets setup
- [RELEASE.md](RELEASE.md) - Detailed release guide
- [scripts/SECRETS_SETUP.md](scripts/SECRETS_SETUP.md) - Comprehensive secrets guide
