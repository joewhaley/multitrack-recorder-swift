# GitHub Secrets Setup Guide

This guide provides step-by-step instructions for setting up GitHub secrets required for automated releases.

## Prerequisites

1. An Apple Developer account
2. A **Developer ID Application** certificate
3. Access to your GitHub repository settings

## Step 1: Export Your Developer Certificate

### Export from Keychain Access

1. Open **Keychain Access** (Applications → Utilities → Keychain Access)
2. In the left sidebar, select **login** keychain
3. Select **My Certificates** category
4. Find your **Developer ID Application: Your Name (TEAM_ID)** certificate
5. Right-click the certificate → **Export "Developer ID Application: Your Name"**
6. Save as `certificate.p12`
7. **Set a strong password** when prompted (you'll need this for the `P12_PASSWORD` secret)
8. Save the file to a secure location

### Convert to Base64

Open Terminal and run:

```bash
base64 -i ~/Downloads/certificate.p12 | pbcopy
```

This copies the base64-encoded certificate to your clipboard. You'll paste this into the `BUILD_CERTIFICATE_BASE64` secret.

## Step 2: Get Your Apple Team ID

### From Developer Portal

1. Go to [Apple Developer Account](https://developer.apple.com/account)
2. Sign in with your Apple ID
3. Look for your **Team ID** in the membership details
   - Usually a 10-character alphanumeric string (e.g., `ABCD123456`)
4. Copy this value for the `APPLE_TEAM_ID` secret

### From Keychain (Alternative)

1. In Keychain Access, select your Developer ID Application certificate
2. Press `Cmd+I` to open certificate info
3. Look for **Organizational Unit** - this is your Team ID

## Step 3: Create App-Specific Password

1. Go to [Apple ID Account Page](https://appleid.apple.com/)
2. Sign in with your Apple ID
3. Navigate to **Security** section
4. Under **App-Specific Passwords**, click **Generate Password**
5. Enter a label like "GitHub Actions MultitrackRecorder"
6. Click **Create**
7. **Copy the generated password** (format: `xxxx-xxxx-xxxx-xxxx`)
   - ⚠️ You won't be able to see this password again!
8. Save this for the `APPLE_APP_SPECIFIC_PASSWORD` secret

## Step 4: Configure GitHub Secrets

### Access Repository Secrets

1. Go to your GitHub repository
2. Click **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** for each secret below

### Add These Secrets

| Secret Name | Value | Notes |
|------------|-------|-------|
| `BUILD_CERTIFICATE_BASE64` | The base64 string from Step 1 | Paste from clipboard |
| `P12_PASSWORD` | Password you set when exporting | The password from Step 1 |
| `KEYCHAIN_PASSWORD` | Any random secure password | Generate a random string (e.g., `openssl rand -base64 32`) |
| `CODE_SIGN_IDENTITY` | Full certificate name | e.g., `Developer ID Application: John Doe (ABCD123456)` |
| `APPLE_ID` | Your Apple ID email | The email for your Apple Developer account |
| `APPLE_TEAM_ID` | Your Team ID | From Step 2 (e.g., `ABCD123456`) |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | From Step 3 (format: `xxxx-xxxx-xxxx-xxxx`) |

### Finding Your Code Sign Identity

If you're not sure of the exact certificate name, run this in Terminal:

```bash
security find-identity -v -p codesigning
```

Look for an entry like:
```
1) ABCD1234... "Developer ID Application: John Doe (ABCD123456)"
```

Copy the full name in quotes (including the Team ID in parentheses) for the `CODE_SIGN_IDENTITY` secret.

## Step 5: Verify Setup

### Test Locally First

Before pushing a tag, test the build script locally:

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

./scripts/build_release.sh
```

If this succeeds, your GitHub Actions should work too.

### Test GitHub Actions

After setting up secrets, you can test the workflow:

1. Go to **Actions** tab in your repository
2. Select **Build and Release** workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**
5. Watch the workflow run and check for errors

## Security Best Practices

### Certificate Security

- ✅ **DO** use repository secrets (not environment variables)
- ✅ **DO** limit access to your certificate files
- ✅ **DO** delete local certificate.p12 after uploading to GitHub
- ✅ **DO** use strong, unique passwords for P12 export
- ❌ **DON'T** commit certificate files to git
- ❌ **DON'T** share your app-specific password
- ❌ **DON'T** use the same password for multiple purposes

### Revoking Access

If you need to revoke access:

1. **App-Specific Password**: Delete it from appleid.apple.com
2. **Certificate**: Revoke it from developer.apple.com
3. **GitHub Secrets**: Delete and recreate secrets in repository settings

## Troubleshooting

### "Unable to find identity" Error

**Problem**: GitHub Actions can't find your signing identity.

**Solution**:
1. Verify `CODE_SIGN_IDENTITY` matches your certificate name exactly
2. Check that `BUILD_CERTIFICATE_BASE64` is complete (no truncation)
3. Ensure `P12_PASSWORD` is correct

### "Invalid password" Error

**Problem**: The P12 password is incorrect.

**Solution**:
1. Re-export your certificate with a new password
2. Update both `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD` secrets

### Notarization Fails

**Problem**: Apple rejects notarization.

**Solution**:
1. Verify `APPLE_ID` is correct
2. Check that `APPLE_APP_SPECIFIC_PASSWORD` hasn't expired
3. Ensure `APPLE_TEAM_ID` matches your Developer account
4. Run locally to see detailed error messages

### "Certificate has expired"

**Problem**: Your Developer ID certificate has expired.

**Solution**:
1. Renew certificate at developer.apple.com
2. Download new certificate
3. Re-export as P12
4. Update `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD` secrets

## Certificate Renewal

Developer ID certificates are valid for 5 years. When renewal is needed:

1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Renew or create new Developer ID Application certificate
3. Download and install in Keychain
4. Follow Steps 1-4 above to update GitHub secrets
5. Test with a new build

## Additional Resources

- [Apple Developer: Creating Certificates](https://developer.apple.com/support/certificates/)
- [Apple Developer: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [GitHub: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Xcode: Code Signing](https://developer.apple.com/support/code-signing/)

## Quick Reference Commands

```bash
# Find your code signing identity
security find-identity -v -p codesigning

# Check certificate expiration
security find-certificate -c "Developer ID Application" -p | openssl x509 -text | grep "Not After"

# Convert P12 to base64
base64 -i certificate.p12 | pbcopy

# Generate random password for KEYCHAIN_PASSWORD
openssl rand -base64 32

# Test local build
./scripts/build_release.sh

# Verify notarization
spctl -a -vvv -t install /path/to/app.app
```
