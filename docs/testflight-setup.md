# TestFlight Setup Guide

This guide explains how to set up automated TestFlight deployment for your Flutter iOS app using GitHub Actions.

## Prerequisites

- Apple Developer Account
- App Store Connect access
- GitHub repository with Actions enabled

## Step 1: Create App Store Connect API Key

1. **Log in to App Store Connect**

   - Go to [App Store Connect](https://appstoreconnect.apple.com/)
   - Sign in with your Apple Developer account

2. **Navigate to Users and Access**

   - Click on "Users and Access" in the sidebar
   - Go to the "Keys" tab

3. **Create a New API Key**

   - Click the "+" button to create a new key
   - Select role: **App Manager** (minimum required for TestFlight uploads)
   - Enter a name for your key (e.g., "GitHub Actions TestFlight")

4. **Download the Key**
   - Click "Generate API Key"
   - Download the `.p8` file (you can only download this once!)
   - Note down the **Key ID** and **Issuer ID**

## Step 2: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. **Go to Repository Settings**

   - Navigate to your GitHub repository
   - Click on "Settings" tab
   - Go to "Secrets and variables" → "Actions"

2. **Add Required Secrets**

   | Secret Name                | Description                      | Value                                     |
   | -------------------------- | -------------------------------- | ----------------------------------------- |
   | `APPSTORE_API_PRIVATE_KEY` | Private key content              | Copy the entire content of the `.p8` file |
   | `APPSTORE_API_KEY_ID`      | Key ID from App Store Connect    | The 10-character Key ID                   |
   | `APPSTORE_API_ISSUER_ID`   | Issuer ID from App Store Connect | The UUID Issuer ID                        |

### How to Get the Private Key Content

```bash
# Copy the entire content of the .p8 file
cat AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Or manually copy the content between the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines.

## Step 3: Update Bundle Identifier

Make sure your app's bundle identifier matches what's configured in App Store Connect:

```yaml
# In your CI/CD workflow, update the bundle-id if needed
# The action will automatically detect it from the IPA, but you can also specify it
```

## Step 4: Test the Deployment

1. **Push to Main Branch**

   - The CI/CD pipeline will automatically trigger on pushes to `main`
   - Monitor the Actions tab in your GitHub repository

2. **Check TestFlight**
   - Go to App Store Connect → TestFlight
   - Your build should appear in the "Processing" or "Ready to Submit" state

## Step 5: Configure TestFlight Settings

1. **Add Test Information**

   - Go to TestFlight in App Store Connect
   - Select your build
   - Add test information and release notes

2. **Add Internal Testers**

   - Go to "Internal Testing"
   - Add team members as internal testers

3. **Add External Testers (Optional)**
   - Go to "External Testing"
   - Create a new group and add external testers
   - Submit for Beta App Review

## Troubleshooting

### Common Issues

1. **"Invalid API Key" Error**

   - Verify the private key content is correct
   - Ensure no extra spaces or characters are included
   - Check that the Key ID and Issuer ID are correct

2. **"Bundle ID Mismatch" Error**

   - Ensure your app's bundle identifier matches App Store Connect
   - Check `ios/Runner/Info.plist` for the correct `CFBundleIdentifier`

3. **"Build Already Exists" Error**

   - Increment your app version in `pubspec.yaml`
   - Update the build number in `ios/Runner.xcodeproj`

4. **"Missing Required Icon" Error**
   - Ensure all required app icons are present
   - Check `ios/Runner/Assets.xcassets/AppIcon.appiconset`

### Debug Steps

1. **Check GitHub Actions Logs**

   - Go to Actions tab in your repository
   - Click on the failed workflow run
   - Expand the "Upload to TestFlight" step to see detailed error messages

2. **Verify Secrets**

   - Ensure all three secrets are properly set
   - Check that the private key content is complete

3. **Test Locally**
   - Try building the IPA locally first:
   ```bash
   flutter build ios --release --no-codesign
   cd build/ios/iphoneos
   mkdir -p Payload
   cp -r Runner.app Payload/
   zip -r ../Runner.ipa Payload
   ```

## Security Best Practices

1. **Limit API Key Permissions**

   - Use the minimum required role (App Manager)
   - Regularly rotate API keys

2. **Secure Secret Storage**

   - Never commit API keys to your repository
   - Use GitHub Secrets for all sensitive data

3. **Monitor Usage**
   - Regularly check App Store Connect for API key usage
   - Monitor GitHub Actions logs for any suspicious activity

## Additional Configuration

### Custom Upload Options

You can customize the TestFlight upload with additional options:

```yaml
- name: Upload to TestFlight
  uses: apple-actions/upload-testflight-build@v3
  with:
    app-path: build/ios/Runner.ipa
    issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
    api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
    api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
    # Optional: Add release notes
    release-notes: "Automated build from GitHub Actions"
    # Optional: Skip waiting for processing
    skip-waiting-for-build-processing: false
```

### Environment-Specific Deployments

You can create different workflows for different environments:

```yaml
# Deploy to TestFlight on main branch
if: github.ref == 'refs/heads/main'

# Deploy to TestFlight on develop branch for internal testing
if: github.ref == 'refs/heads/develop'
```

## Support

For issues with the TestFlight upload action, check:

- [Apple Actions TestFlight Upload](https://github.com/Apple-Actions/upload-testflight-build)
- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [Flutter iOS Deployment Guide](https://docs.flutter.dev/deployment/ios)

## Related Documentation

- [Flutter Deployment Rules](../FLUTTER_RULES_TESTING_GUIDE.md)
- [CI/CD Pipeline Configuration](../.github/workflows/ci_cd.yml)
- [iOS Development Setup](../docs/ios-setup.md)
