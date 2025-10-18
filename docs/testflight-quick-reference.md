# TestFlight Quick Setup Reference

## Required GitHub Secrets

| Secret Name                | Description           | Example                                                                            |
| -------------------------- | --------------------- | ---------------------------------------------------------------------------------- |
| `APPSTORE_API_PRIVATE_KEY` | Content of `.p8` file | `-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...` |
| `APPSTORE_API_KEY_ID`      | 10-character Key ID   | `ABC123DEF4`                                                                       |
| `APPSTORE_ISSUER_ID`       | UUID Issuer ID        | `12345678-1234-1234-1234-123456789012`                                             |

## App Store Connect API Key Setup

1. **App Store Connect** → **Users and Access** → **Keys**
2. **Create API Key** with **App Manager** role
3. **Download `.p8` file** (only once!)
4. **Copy Key ID** and **Issuer ID**

## Getting Private Key Content

```bash
# Method 1: Using cat and pbcopy (macOS)
cat AuthKey_XXXXXXXXXX.p8 | pbcopy

# Method 2: Manual copy
# Copy everything between -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
```

## Workflow Triggers

- **Main Branch**: Automatic TestFlight upload
- **Pull Requests**: Code quality checks only
- **Manual**: Can be triggered manually from Actions tab

## Build Output

- **IPA File**: `build/ios/Runner.ipa`
- **TestFlight**: Available in App Store Connect → TestFlight
- **Processing Time**: Usually 5-15 minutes

## Common Issues & Solutions

| Issue                | Solution                                              |
| -------------------- | ----------------------------------------------------- |
| Invalid API Key      | Check private key content (no extra spaces)           |
| Bundle ID Mismatch   | Verify `ios/Runner/Info.plist`                        |
| Build Already Exists | Increment version in `pubspec.yaml`                   |
| Missing Icons        | Check `ios/Runner/Assets.xcassets/AppIcon.appiconset` |

## Verification Steps

1. ✅ API Key created with App Manager role
2. ✅ All three secrets added to GitHub
3. ✅ Bundle ID matches App Store Connect
4. ✅ App version incremented
5. ✅ All required app icons present

## TestFlight Access

- **Internal Testing**: Immediate access for team members
- **External Testing**: Requires Beta App Review (24-48 hours)
- **App Store**: Requires full App Review (1-7 days)

---

**Need Help?** Check the full [TestFlight Setup Guide](./testflight-setup.md) for detailed instructions.
