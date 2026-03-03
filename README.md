# Masquerade - Flutter Multi-Platform Utility Toolbox

A Flutter application that provides utility tools across web, iOS, and Android platforms with automated CI/CD deployment.

## 🚀 Features

- **Multi-Platform Support**: Web, iOS, and Android
- **Automated CI/CD**: GitHub Actions pipeline for all platforms
- **Utility Tools**: Timestamp conversion, QR code scanning, and more
- **Modern Architecture**: Clean architecture with proper separation of concerns
- **Comprehensive Testing**: Unit tests, widget tests, and integration tests

## 📱 Platforms

| Platform | Status | Deployment |
|----------|--------|------------|
| **Web** | ✅ Ready | Firebase Hosting |
| **iOS** | ✅ Ready | TestFlight |
| **Android** | ✅ Ready | Google Play Store |

## 🛠️ Development

### Prerequisites

- Flutter SDK (3.16.0+)
- Dart SDK
- iOS development: Xcode and iOS Simulator
- Android development: Android Studio and Android SDK
- Web development: Chrome browser

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/masquerade.git
   cd masquerade
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Web
   flutter run -d chrome

   # iOS
   flutter run -d ios

   # Android
   flutter run -d android
   ```

### Testing

```bash
# Run all tests
flutter test

# Run specific test types
flutter test test/unit/          # Unit tests
flutter test test/widgets/      # Widget tests
flutter test integration_test/  # Integration tests
```

## 🚀 Deployment

This project includes automated CI/CD pipelines for all platforms. See the comprehensive deployment documentation:

### Quick Start
- **[Deployment Overview](docs/deployment-overview.md)** - Complete deployment strategy
- **[Firebase Hosting Quick Reference](docs/firebase-hosting-quick-reference.md)** - Web deployment
- **[TestFlight Quick Reference](docs/testflight-quick-reference.md)** - iOS deployment
- **[Google Play Quick Reference](docs/google-play-quick-reference.md)** - Android deployment

### Detailed Guides
- **[Firebase Hosting Setup](docs/firebase-hosting-setup.md)** - Complete web deployment guide
- **[TestFlight Setup Guide](docs/testflight-setup.md)** - Complete iOS TestFlight deployment
- **[Google Play Store Setup](docs/google-play-setup.md)** - Complete Android Play Store deployment

### Required Secrets

| Platform | Required Secrets |
|----------|------------------|
| **Web** | `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID` |
| **iOS** | `APPSTORE_API_PRIVATE_KEY`, `APPSTORE_API_KEY_ID`, `APPSTORE_ISSUER_ID` |
| **Android** | `GOOGLE_PLAY_SERVICE_ACCOUNT` |

## 🏗️ Architecture

This project follows Flutter best practices and clean architecture principles:

```
lib/
├── app/                     # App-level configuration
├── core/                   # Shared utilities and constants
├── features/               # Feature-based organization
├── shared/                 # Shared components
└── platform/               # Platform-specific implementations
```

### Key Components

- **State Management**: Built-in Flutter solutions (ValueNotifier, ChangeNotifier)
- **Navigation**: GoRouter for declarative routing
- **Data Management**: Repository pattern with local and remote data sources
- **Error Handling**: Comprehensive error handling with custom exceptions
- **Testing**: Comprehensive test coverage with unit, widget, and integration tests

## 📚 Documentation

- **[Complete Documentation](docs/README.md)** - All deployment and development guides
- **[Flutter Architecture Rules](FLUTTER_RULES_TESTING_GUIDE.md)** - Development guidelines
- **[CI/CD Pipeline](.github/workflows/ci_cd.yml)** - Automated deployment configuration

## 🔧 Development Tools

### Code Quality
- **Linting**: `flutter analyze`
- **Formatting**: `dart format`
- **Testing**: `flutter test`

### CI/CD Pipeline
- **Code Quality**: Automated linting, formatting, and testing
- **Multi-Platform Builds**: Web, iOS, and Android
- **Automated Deployment**: Firebase Hosting, TestFlight, and Play Store
- **Security Scanning**: Automated security checks
- **Performance Testing**: Coverage and performance metrics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow the [Flutter Architecture Rules](FLUTTER_RULES_TESTING_GUIDE.md)
- Write tests for new features
- Ensure all tests pass
- Follow the existing code style
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for hosting and analytics
- Apple for TestFlight platform
- Google for Play Store platform
- GitHub for Actions and hosting

## 📞 Support

- **Documentation**: Check the [docs](docs/) folder for comprehensive guides
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Flutter Help**: [Flutter Documentation](https://docs.flutter.dev/)

---

**Built with ❤️ using Flutter**
