# Release Process

This document describes how to create signed, notarized releases of MultitrackRecorder for macOS distribution.

## Prerequisites

### 1. Apple Developer Account

You need an Apple Developer account with:
- A valid **Developer ID Application** certificate
- Access to App Store Connect for notarization

### 2. Code Signing Certificate

1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Create a **Developer ID Application** certificate
3. Download and install it in your Keychain

### 3. App-Specific Password

For notarization, you need an app-specific password:

1. Go to [Apple ID account page](https://appleid.apple.com/)
2. Sign in and go to **Security** → **App-Specific Passwords**
3. Generate a new password
4. Save this password securely (you'll need it for notarization)

## Local Build

### Building Without Notarization (for testing)

```bash
# Set your code signing identity
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_TEAM_ID="YOUR_TEAM_ID"

# Run the build script
./scripts/build_release.sh
```

The script will:
- Build a universal binary (arm64 + x86_64)
- Sign the app with your Developer ID
- Create a DMG file
- Skip notarization (since credentials aren't set)

Output will be in `build/MultitrackRecorder.dmg`.

### Building With Notarization (for distribution)

```bash
# Set all required environment variables
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# Run the build script
./scripts/build_release.sh
```

The script will:
- Build a universal binary (arm64 + x86_64)
- Sign the app with your Developer ID
- Create and sign a DMG file
- Submit to Apple for notarization
- Wait for notarization to complete
- Staple the notarization ticket to the DMG
- Generate a SHA256 checksum

Output will be in `build/MultitrackRecorder.dmg`.

## Automated GitHub Releases

### Setting Up GitHub Secrets

To enable automated releases via GitHub Actions, you need to configure the following secrets in your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

#### Required Secrets

| Secret Name | Description | How to Get |
|------------|-------------|-----------|
| `BUILD_CERTIFICATE_BASE64` | Your Developer ID certificate in base64 | See instructions below |
| `P12_PASSWORD` | Password for the P12 certificate | The password you set when exporting |
| `KEYCHAIN_PASSWORD` | Temporary keychain password | Any secure random string |
| `CODE_SIGN_IDENTITY` | Full signing identity name | e.g., "Developer ID Application: Your Name (TEAM_ID)" |
| `APPLE_ID` | Your Apple ID email | Your developer account email |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID | Found in developer.apple.com |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | Generated from appleid.apple.com |

#### Exporting Your Certificate

To export your Developer ID certificate as base64:

```bash
# Export certificate from Keychain
# 1. Open Keychain Access
# 2. Find your "Developer ID Application" certificate
# 3. Right-click → Export
# 4. Save as .p12 file with a password

# Convert to base64
base64 -i certificate.p12 | pbcopy
```

The base64 string is now in your clipboard. Paste it into the `BUILD_CERTIFICATE_BASE64` secret.

### Creating a Release

Once secrets are configured, create a release by pushing a version tag:

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

This will trigger the GitHub Actions workflow which will:
1. Build the universal app
2. Sign it with your Developer ID
3. Create a DMG
4. Notarize the DMG with Apple
5. Create a GitHub release
6. Upload the DMG and checksums to the release

### Manual Release Trigger

You can also trigger a release manually:

1. Go to **Actions** tab in your GitHub repository
2. Select **Build and Release** workflow
3. Click **Run workflow**
4. Choose the branch and click **Run workflow**

## Verifying a Release

After downloading a DMG from GitHub releases:

```bash
# Verify checksum
shasum -a 256 -c MultitrackRecorder-1.0.0.dmg.sha256

# Verify code signature
codesign -vvv --deep --strict /Volumes/MultitrackRecorder/MultitrackRecorder.app

# Verify notarization
spctl -a -vvv -t install /Volumes/MultitrackRecorder/MultitrackRecorder.app
```

## Architecture Support

All releases are universal binaries that run natively on:
- **Apple Silicon** (M1, M2, M3, etc.) - arm64
- **Intel Macs** - x86_64

## Troubleshooting

### Notarization Failed

If notarization fails:
1. Check the notarization logs using the submission ID from the error message
2. Common issues:
   - Unsigned binaries or frameworks
   - Missing hardened runtime entitlements
   - Invalid bundle structure

### Code Signing Issues

If code signing fails:
1. Verify your certificate is installed: `security find-identity -v -p codesigning`
2. Ensure the certificate hasn't expired
3. Check that your Team ID matches the certificate

### PortAudio Linking Issues

If the app fails to find PortAudio:
1. Ensure PortAudio is installed: `brew install portaudio`
2. Verify the library location: `ls -la /opt/homebrew/lib/libportaudio.*`
3. Update library search paths in the build script if using a different location

## Version Numbering

Follow semantic versioning (semver):
- **Major** (v2.0.0): Breaking changes
- **Minor** (v1.1.0): New features, backwards compatible
- **Patch** (v1.0.1): Bug fixes, backwards compatible

## Release Checklist

Before creating a release:

- [ ] Update version number in Xcode project
- [ ] Update MARKETING_VERSION in project.pbxproj if needed
- [ ] Test the app locally
- [ ] Build and test the release DMG locally
- [ ] Update README.md with any new features/changes
- [ ] Create git tag with version number
- [ ] Push tag to trigger automated release
- [ ] Verify GitHub Actions workflow completes successfully
- [ ] Test the downloaded DMG on both Intel and Apple Silicon Macs (if possible)
- [ ] Verify notarization by testing Gatekeeper on a clean Mac

## Resources

- [Apple Developer: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple Developer: Code Signing](https://developer.apple.com/support/code-signing/)
- [GitHub Actions: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
