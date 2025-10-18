# Google Play Store Quick Setup Reference

## Required GitHub Secret

| Secret Name                   | Description                  | Example                                                                 |
| ----------------------------- | ---------------------------- | ----------------------------------------------------------------------- |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Service account JSON content | `{"type": "service_account", "project_id": "my-project", "private_key_id": "abc123"...}` |

## Google Cloud Service Account Setup

1. **Google Cloud Console** → **IAM & Admin** → **Service Accounts**
2. **Create Service Account** with "Service Account User" role
3. **Create JSON Key** and download the file
4. **Enable Google Play Developer API** in the project

## Play Console Linking

1. **Play Console** → **Setup** → **API access**
2. **Link Google Cloud project** (or create new)
3. **Grant access** to service account with permissions:
   - App information: View app information
   - Pricing & distribution: View pricing and distribution
   - Release management: Manage app releases

## Getting Service Account JSON Content

```bash
# Method 1: Using cat and pbcopy (macOS)
cat path/to/service-account-key.json | pbcopy

# Method 2: Manual copy
# Copy the entire JSON content including all curly braces
```

## Workflow Configuration

```yaml
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
    packageName: com.yourcompany.yourapp
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: internal  # internal, alpha, beta, production
    status: completed  # draft, completed
```

## Release Tracks

| Track      | Purpose                    | Review Required | Rollout Time |
| ---------- | -------------------------- | --------------- | ------------ |
| Internal   | Team testing               | No              | Immediate    |
| Alpha      | Limited external testing   | No              | Immediate    |
| Beta       | Public beta testing         | No              | Immediate    |
| Production | Public release             | Yes             | 1-3 days     |

## Build Output

- **APK File**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB File**: `build/app/outputs/bundle/release/app-release.aab`
- **Play Console**: Available in Release → Internal testing

## Common Issues & Solutions

| Issue                      | Solution                                                      |
| -------------------------- | ------------------------------------------------------------- |
| Service Account Not Found  | Verify JSON content and Play Console linking                  |
| Package Name Mismatch      | Check `android/app/build.gradle` applicationId               |
| Version Code Already Exists| Increment build number in `pubspec.yaml`                     |
| App Not Found              | Verify app exists in Play Console with correct package name   |
| Permission Denied          | Check service account permissions in Play Console            |

## Verification Steps

1. ✅ Service account created in Google Cloud Console
2. ✅ Google Play Developer API enabled
3. ✅ Service account linked to Play Console
4. ✅ Service account has proper permissions
5. ✅ JSON secret added to GitHub
6. ✅ Package name matches Play Console
7. ✅ App version incremented

## App Configuration

```gradle
// android/app/build.gradle
android {
    defaultConfig {
        applicationId "com.yourcompany.yourapp"  // Must match Play Console
        versionCode 1
        versionName "1.0.0"
    }
}
```

```yaml
# pubspec.yaml
version: 1.0.0+1  # Format: version+buildNumber
```

## Testing Access

- **Internal Testing**: Immediate access for team members
- **Alpha/Beta Testing**: Immediate access for testers
- **Production**: Requires Google Play review (1-3 days)

---

**Need Help?** Check the full [Google Play Store Setup Guide](./google-play-setup.md) for detailed instructions.
