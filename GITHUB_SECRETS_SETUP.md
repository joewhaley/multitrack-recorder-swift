# GitHub Secrets Setup - Quick Start

This guide shows you how to configure GitHub Secrets for automated releases.

## Your Values from publish.sh

Check your local `publish.sh` file for your actual values. They should look like:

```bash
APPLE_ID="your@email.com"
APPLE_TEAM_ID="YOUR_TEAM_ID"
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (YOUR_TEAM_ID)"
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## Required GitHub Secrets

You need to configure **7 secrets** in your GitHub repository:

### 1. Navigate to Repository Settings

1. Go to your repository on GitHub
2. Click **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** for each secret below

### 2. Add These Secrets

| Secret Name | Value | Notes |
|------------|-------|-------|
| `APPLE_ID` | `your@email.com` | Your Apple Developer account email |
| `APPLE_TEAM_ID` | `YOUR_TEAM_ID` | Your Team ID (10 characters, e.g., ABC1234DEF) |
| `CODE_SIGN_IDENTITY` | `Developer ID Application: Your Name (YOUR_TEAM_ID)` | Full certificate name |
| `APPLE_APP_SPECIFIC_PASSWORD` | `xxxx-xxxx-xxxx-xxxx` | App-specific password from appleid.apple.com |
| `BUILD_CERTIFICATE_BASE64` | *(see below)* | Your certificate in base64 format |
| `P12_PASSWORD` | *(see below)* | Password you set when exporting certificate |
| `KEYCHAIN_PASSWORD` | *(any secure random string)* | Temporary password for GitHub Actions keychain |

### 3. Export Your Certificate

#### Step 1: Export from Keychain

1. Open **Keychain Access** (Applications → Utilities)
2. In the left sidebar, select **login** keychain
3. Select **My Certificates** category
4. Find your **Developer ID Application** certificate (the one matching your CODE_SIGN_IDENTITY)
5. Right-click → **Export "Developer ID Application: Your Name"**
6. Save as: `certificate.p12`
7. **Set a password** when prompted (remember this for `P12_PASSWORD`)
8. Save to your Desktop

#### Step 2: Convert to Base64

Open Terminal and run:

```bash
# Convert certificate to base64
base64 -i ~/Desktop/certificate.p12 | pbcopy
```

The base64 string is now in your clipboard.

#### Step 3: Add to GitHub Secrets

1. Go to GitHub → Settings → Secrets → New repository secret
2. Name: `BUILD_CERTIFICATE_BASE64`
3. Value: Paste from clipboard (Cmd+V)
4. Click **Add secret**

### 4. Add P12_PASSWORD

1. Click **New repository secret**
2. Name: `P12_PASSWORD`
3. Value: The password you set in Step 1 above
4. Click **Add secret**

### 5. Add KEYCHAIN_PASSWORD

Generate a random password:

```bash
openssl rand -base64 32 | pbcopy
```

1. Click **New repository secret**
2. Name: `KEYCHAIN_PASSWORD`
3. Value: Paste from clipboard
4. Click **Add secret**

## Verification Checklist

After adding all secrets, verify you have these 7 secrets:

- [ ] `APPLE_ID`
- [ ] `APPLE_TEAM_ID`
- [ ] `CODE_SIGN_IDENTITY`
- [ ] `APPLE_APP_SPECIFIC_PASSWORD`
- [ ] `BUILD_CERTIFICATE_BASE64`
- [ ] `P12_PASSWORD`
- [ ] `KEYCHAIN_PASSWORD`

## How GitHub Actions Uses These Secrets

The workflow (`.github/workflows/release.yml`) automatically:

1. **Imports the certificate** using `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD`
2. **Creates a temporary keychain** using `KEYCHAIN_PASSWORD`
3. **Builds and signs** the app using `CODE_SIGN_IDENTITY`
4. **Notarizes** using `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`

## Test the Workflow

Once secrets are configured:

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Build the universal app
2. Sign with your Developer ID
3. Create a DMG
4. Notarize with Apple
5. Create a GitHub release
6. Upload the signed DMG

## Troubleshooting

### "Invalid certificate" error

- Verify `BUILD_CERTIFICATE_BASE64` was copied completely
- Ensure `P12_PASSWORD` matches the password you set during export
- Check that the certificate hasn't expired

### "Invalid credentials" during notarization

- Verify `APPLE_ID` is correct
- Check that `APPLE_APP_SPECIFIC_PASSWORD` is valid (not your main Apple ID password)
- Ensure `APPLE_TEAM_ID` matches your Developer account

### How to update secrets

1. Go to Settings → Secrets and variables → Actions
2. Click the secret name
3. Click **Update secret**
4. Enter new value and click **Update secret**

## Security Notes

✅ **DO:**
- Keep secrets confidential
- Rotate passwords periodically
- Use app-specific passwords (never your main Apple ID password)

❌ **DON'T:**
- Commit secrets to git
- Share secrets in issues or pull requests
- Use the same password for multiple purposes

## Need More Help?

- Detailed setup guide: See `scripts/SECRETS_SETUP.md`
- GitHub Actions logs: Check the Actions tab in your repository
- Apple docs: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

---

**Quick Copy-Paste Reference:**

```bash
# Export and convert certificate
base64 -i ~/Desktop/certificate.p12 | pbcopy

# Generate keychain password
openssl rand -base64 32 | pbcopy
```

Find your values in your local `publish.sh` file (NOT committed to git).
