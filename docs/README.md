# Flutter Multi-Platform Deployment Documentation

This directory contains comprehensive documentation for deploying Flutter applications across multiple platforms using automated CI/CD pipelines.

## 📚 Documentation Overview

### 🚀 Quick Start Guides
- **[Deployment Overview](./deployment-overview.md)** - Complete deployment strategy overview
- **[Firebase Hosting Quick Reference](./firebase-hosting-quick-reference.md)** - Fast Firebase setup
- **[TestFlight Quick Reference](./testflight-quick-reference.md)** - Fast iOS TestFlight setup
- **[Google Play Quick Reference](./google-play-quick-reference.md)** - Fast Android Play Store setup

### 📖 Detailed Setup Guides
- **[Firebase Hosting Setup](./firebase-hosting-setup.md)** - Complete web deployment guide
- **[TestFlight Setup Guide](./testflight-setup.md)** - Complete iOS TestFlight deployment
- **[Google Play Store Setup](./google-play-setup.md)** - Complete Android Play Store deployment

### 🛠️ Development & Testing
- **[GitHub Actions Local Testing](./github-actions-local-testing.md)** - Local CI/CD testing guide

## 🎯 Platform Support

| Platform | Deployment Target | Review Required | Rollout Time | Documentation |
|----------|------------------|-----------------|--------------|---------------|
| **Web** | Firebase Hosting | No | Immediate | [Firebase Setup](./firebase-hosting-setup.md) |
| **iOS** | TestFlight | No (Internal) | Immediate | [TestFlight Setup](./testflight-setup.md) |
| **Android** | Play Store Internal | No | Immediate | [Play Store Setup](./google-play-setup.md) |

## 🔧 Required Secrets

### Web Deployment (Firebase Hosting)
- `FIREBASE_SERVICE_ACCOUNT` - Firebase service account JSON
- `FIREBASE_PROJECT_ID` - Firebase project ID

### iOS Deployment (TestFlight)
- `APPSTORE_API_PRIVATE_KEY` - App Store Connect API private key (.p8 content)
- `APPSTORE_API_KEY_ID` - App Store Connect API key ID
- `APPSTORE_ISSUER_ID` - App Store Connect issuer ID

### Android Deployment (Play Store)
- `GOOGLE_PLAY_SERVICE_ACCOUNT` - Google Cloud service account JSON

## 🚀 Getting Started

### 1. Choose Your Platforms
Decide which platforms you want to deploy to:
- **Web only**: Follow [Firebase Hosting Setup](./firebase-hosting-setup.md)
- **iOS only**: Follow [TestFlight Setup Guide](./testflight-setup.md)
- **Android only**: Follow [Google Play Store Setup](./google-play-setup.md)
- **All platforms**: Follow [Deployment Overview](./deployment-overview.md)

### 2. Set Up Credentials
Each platform requires specific credentials:
- **Firebase**: Service account with Firebase Admin and Hosting Admin roles
- **TestFlight**: App Store Connect API key with App Manager role
- **Play Store**: Google Cloud service account with Play Console access

### 3. Configure GitHub Secrets
Add the required secrets to your GitHub repository:
- Go to Repository Settings → Secrets and variables → Actions
- Add the secrets listed above for your target platforms

### 4. Test Deployment
- Push to `main` branch to trigger automatic deployment
- Monitor the Actions tab for deployment status
- Check your target platform for the deployed app

## 📋 Pre-Deployment Checklist

### General Requirements
- [ ] Flutter app builds successfully locally
- [ ] All tests pass (`flutter test`)
- [ ] Code passes linting (`flutter analyze`)
- [ ] App version incremented in `pubspec.yaml`
- [ ] Required secrets added to GitHub repository

### Web Deployment
- [ ] Firebase project created
- [ ] Firebase Hosting enabled
- [ ] Service account created with proper roles
- [ ] `firebase.json` configured
- [ ] Custom domain configured (optional)

### iOS Deployment
- [ ] Apple Developer account active
- [ ] App registered in App Store Connect
- [ ] App Store Connect API key created
- [ ] Bundle ID matches App Store Connect
- [ ] App icons and metadata configured

### Android Deployment
- [ ] Google Play Console account active
- [ ] App created in Play Console
- [ ] Google Cloud service account created
- [ ] Package name matches Play Console
- [ ] App signing configured

## 🔍 Troubleshooting

### Common Issues
- **Build Failures**: Check Flutter version, dependencies, and local build
- **Deployment Failures**: Verify secrets, API permissions, and account status
- **Test Failures**: Review test logs, environment, and test data

### Debug Steps
1. **Check GitHub Actions Logs**: Go to Actions tab → Failed workflow → Expand failed steps
2. **Test Locally**: Build and test deployment manually
3. **Verify Credentials**: Check secret values and API permissions
4. **Review Documentation**: Check platform-specific setup guides

### Getting Help
- Check the troubleshooting sections in each setup guide
- Review the quick reference cards for common issues
- Consult platform-specific documentation links
- Check GitHub Actions logs for detailed error messages

## 📊 CI/CD Pipeline

The automated pipeline includes:

### Code Quality Stage
- Linting (`flutter analyze`)
- Formatting (`dart format --set-exit-if-changed`)
- Testing (`flutter test`)

### Build Stage
- Web: `flutter build web --release`
- iOS: `flutter build ios --release --no-codesign` + IPA creation
- Android: `flutter build apk --release` + `flutter build appbundle --release`

### Deployment Stage
- Web: Firebase Hosting deployment
- iOS: TestFlight upload
- Android: Play Store internal track upload

### Testing Stage
- Integration tests (`flutter test integration_test/`)
- Security scans
- Performance tests

## 🔒 Security Best Practices

### Secret Management
- Use GitHub Secrets for all sensitive data
- Never commit API keys or certificates
- Regularly rotate credentials
- Monitor secret usage

### Access Control
- Use minimum required permissions
- Implement role-based access
- Regular access reviews
- Audit trail maintenance

### Code Security
- Regular security scans
- Dependency vulnerability checks
- Code quality gates
- Secure coding practices

## 📈 Monitoring and Analytics

### Error Tracking
- Firebase Crashlytics
- Sentry integration
- Custom error logging
- Performance monitoring

### Analytics
- User behavior tracking
- Performance metrics
- Deployment success rates
- Build time monitoring

## 🔗 Related Resources

### External Documentation
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)

### Project Files
- [CI/CD Pipeline Configuration](../.github/workflows/ci_cd.yml)
- [Flutter Architecture Rules](../FLUTTER_RULES_TESTING_GUIDE.md)
- [Project README](../README.md)

## 🤝 Contributing

To contribute to this documentation:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test the documentation**
5. **Submit a pull request**

### Documentation Standards
- Use clear, concise language
- Include code examples where helpful
- Provide troubleshooting sections
- Keep information up-to-date
- Follow markdown best practices

## 📝 License

This documentation is part of the Flutter Multi-Platform Project and follows the same license terms.

---

**Need Help?** Start with the [Deployment Overview](./deployment-overview.md) for a complete understanding of the deployment strategy, or jump directly to the platform-specific setup guides for your target platforms.
