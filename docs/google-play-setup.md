# Google Play Store Setup Guide

This guide explains how to set up automated Google Play Store deployment for your Flutter Android app using GitHub Actions.

## Prerequisites

- Google Play Console account
- Google Cloud Platform account
- Android app registered in Google Play Console
- GitHub repository with Actions enabled

## Step 1: Create Google Cloud Service Account

1. **Go to Google Cloud Console**
   - Navigate to [Google Cloud Console](https://console.cloud.google.com/)
   - Sign in with your Google account

2. **Select or Create a Project**
   - Choose an existing project or create a new one
   - Note the Project ID for later use

3. **Enable Google Play Developer API**
   - Go to "APIs & Services" → "Library"
   - Search for "Google Play Developer API"
   - Click on it and press "Enable"

4. **Create Service Account**
   - Go to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Enter a name (e.g., "GitHub Actions Play Store")
   - Add description: "Service account for automated Play Store uploads"
   - Click "Create and Continue"

5. **Assign Roles**
   - Add role: "Service Account User"
   - Click "Continue" and then "Done"

6. **Create and Download Key**
   - Click on the created service account
   - Go to "Keys" tab
   - Click "Add Key" → "Create new key"
   - Choose "JSON" format
   - Click "Create" (this downloads the JSON file)

## Step 2: Link Service Account to Play Console

1. **Go to Google Play Console**
   - Navigate to [Google Play Console](https://play.google.com/console/)
   - Sign in with your Google account

2. **Access Setup Section**
   - Select your app from the dashboard
   - Go to "Setup" → "API access"

3. **Link Service Account**
   - Click "Link project" next to your Google Cloud project
   - Or click "Create new project" if you haven't linked one yet

4. **Grant Permissions**
   - Find your service account in the list
   - Click "Grant access"
   - Select permissions:
     - **App information**: View app information
     - **Pricing & distribution**: View pricing and distribution
     - **Release management**: Manage app releases
   - Click "Invite user"

5. **Accept Invitation**
   - Go back to Google Cloud Console
   - Check the service account permissions
   - Ensure it has the necessary Play Console access

## Step 3: Configure GitHub Secrets

Add the required secret to your GitHub repository:

1. **Go to Repository Settings**
   - Navigate to your GitHub repository
   - Click on "Settings" tab
   - Go to "Secrets and variables" → "Actions"

2. **Add Required Secret**

   | Secret Name                    | Description                    | Value                                    |
   | ------------------------------ | ------------------------------ | ---------------------------------------- |
   | `GOOGLE_PLAY_SERVICE_ACCOUNT`  | Service account JSON content   | Copy the entire content of the JSON file |

### How to Get the Service Account JSON Content

```bash
# Method 1: Using cat (Linux/macOS)
cat path/to/service-account-key.json | pbcopy

# Method 2: Manual copy
# Copy the entire JSON content including all curly braces
```

## Step 4: Update App Configuration

1. **Update Package Name**
   - Ensure your app's package name matches Play Console
   - Check `android/app/build.gradle`:
   ```gradle
   android {
       defaultConfig {
           applicationId "com.yourcompany.yourapp"  // Must match Play Console
       }
   }
   ```

2. **Update Version Information**
   - Increment version in `pubspec.yaml`:
   ```yaml
   version: 1.0.0+1  # Format: version+buildNumber
   ```

3. **Configure Signing (if needed)**
   - For release builds, configure signing in `android/app/build.gradle`
   - Or use Google Play App Signing (recommended)

## Step 5: Test the Deployment

1. **Push to Main Branch**
   - The CI/CD pipeline will automatically trigger on pushes to `main`
   - Monitor the Actions tab in your GitHub repository

2. **Check Play Console**
   - Go to Play Console → Your App → Release → Internal testing
   - Your build should appear in the "Draft" or "Review" state

## Step 6: Configure Play Console Settings

1. **Set Up Release Tracks**
   - **Internal testing**: For team testing
   - **Closed testing**: For limited external testing
   - **Open testing**: For public beta testing
   - **Production**: For public release

2. **Add Testers**
   - Go to "Testing" → "Internal testing"
   - Add team members as testers
   - Share the testing link with testers

3. **Configure Release Notes**
   - Add release notes for each build
   - Describe new features and bug fixes

## Troubleshooting

### Common Issues

1. **"Service Account Not Found" Error**
   - Verify the service account JSON is correct
   - Ensure the service account is linked to Play Console
   - Check that the service account has proper permissions

2. **"Package Name Mismatch" Error**
   - Ensure your app's package name matches Play Console
   - Check `android/app/build.gradle` for correct `applicationId`

3. **"Version Code Already Exists" Error**
   - Increment the build number in `pubspec.yaml`
   - Update the version code in `android/app/build.gradle`

4. **"App Not Found" Error**
   - Ensure the app is created in Play Console
   - Verify the package name is exactly correct
   - Check that the app is not in draft state

5. **"Permission Denied" Error**
   - Verify service account has proper permissions
   - Check that the service account is invited to Play Console
   - Ensure the Google Play Developer API is enabled

### Debug Steps

1. **Check GitHub Actions Logs**
   - Go to Actions tab in your repository
   - Click on the failed workflow run
   - Expand the "Upload to Play Store" step to see detailed error messages

2. **Verify Service Account**
   - Check the JSON file content is complete
   - Verify the service account exists in Google Cloud Console
   - Ensure it's linked to Play Console

3. **Test Locally**
   - Try building the AAB locally first:
   ```bash
   flutter build appbundle --release
   ```

4. **Check Play Console**
   - Verify the app exists and is properly configured
   - Check that the package name matches exactly

## Security Best Practices

1. **Limit Service Account Permissions**
   - Use the minimum required permissions
   - Regularly review and rotate service account keys

2. **Secure Secret Storage**
   - Never commit service account keys to your repository
   - Use GitHub Secrets for all sensitive data

3. **Monitor Usage**
   - Regularly check Google Cloud Console for service account usage
   - Monitor GitHub Actions logs for any suspicious activity

## Additional Configuration

### Custom Upload Options

You can customize the Play Store upload with additional options:

```yaml
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
    packageName: com.yourcompany.yourapp
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: internal  # Options: internal, alpha, beta, production
    status: completed  # Options: draft, completed
    # Optional: Add release notes
    releaseNotes: |
      - Bug fixes and improvements
      - New features added
    # Optional: Set rollout percentage
    rolloutPercentage: 20
```

### Environment-Specific Deployments

You can create different workflows for different environments:

```yaml
# Deploy to internal testing on main branch
if: github.ref == 'refs/heads/main'
track: internal

# Deploy to alpha testing on develop branch
if: github.ref == 'refs/heads/develop'
track: alpha
```

### Multiple Release Tracks

```yaml
# Deploy to multiple tracks
- name: Upload to Internal Testing
  uses: r0adkll/upload-google-play@v1
  with:
    track: internal
    status: completed

- name: Upload to Alpha Testing
  uses: r0adkll/upload-google-play@v1
  with:
    track: alpha
    status: draft  # Keep as draft for review
```

## Release Management

### Release Tracks Overview

| Track        | Purpose                    | Review Required | Rollout Time |
| ------------ | -------------------------- | --------------- | ------------ |
| Internal     | Team testing               | No              | Immediate    |
| Alpha        | Limited external testing   | No              | Immediate    |
| Beta         | Public beta testing         | No              | Immediate    |
| Production   | Public release             | Yes             | 1-3 days     |

### Release Process

1. **Internal Testing**
   - Deploy to internal track
   - Test with team members
   - Fix critical issues

2. **Alpha/Beta Testing**
   - Deploy to alpha or beta track
   - Gather user feedback
   - Address reported issues

3. **Production Release**
   - Deploy to production track
   - Submit for review
   - Monitor release metrics

## Support

For issues with the Play Store upload action, check:
- [Google Play Upload Action](https://github.com/r0adkll/upload-google-play)
- [Google Play Developer API Documentation](https://developers.google.com/android-publisher)
- [Flutter Android Deployment Guide](https://docs.flutter.dev/deployment/android)

## Related Documentation

- [Flutter Deployment Rules](../FLUTTER_RULES_TESTING_GUIDE.md)
- [CI/CD Pipeline Configuration](../.github/workflows/ci_cd.yml)
- [Android Development Setup](../docs/android-setup.md)
- [TestFlight Setup Guide](./testflight-setup.md)
