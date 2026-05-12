# CI/CD Setup Guide

This document explains the CI/CD setup for the Flutter project, including pre-commit hooks and GitHub Actions workflows.

## 🚀 Quick Start

### 1. Install Pre-commit Hooks

```bash
# Make the setup script executable
chmod +x setup-precommit.sh

# Run the setup script
./setup-precommit.sh
```

### 2. Manual Setup (Alternative)

If you prefer to set up manually:

```bash
# Install pre-commit
pip3 install pre-commit

# Install hooks
pre-commit install
pre-commit install --hook-type commit-msg

# Run on all files
pre-commit run --all-files
```

## 📋 Pre-commit Hooks

The pre-commit configuration (`.pre-commit-config.yaml`) includes:

### General Hooks

- **Trailing whitespace removal**
- **End-of-file fixer**
- **YAML/JSON/TOML/XML validation**
- **Large file detection**
- **Merge conflict detection**
- **Mixed line ending fixes**

### Flutter-Specific Hooks

- **Dart formatting** (`dart format`)
- **Flutter analysis** (`flutter analyze`)
- **Flutter testing** (`flutter test`)
- **Build verification** (manual trigger)

### Security Hooks

- **Secret detection** (detect-secrets)
- **Commit message linting** (Conventional Commits)

## 🔄 GitHub Actions Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:** Push to `main`/`develop`, Pull Requests

**Jobs:**

- **Test**: Format verification, analysis, testing, coverage
- **Build**: Multi-platform builds (Android, Web, Linux, Windows, macOS)
- **Security**: Trivy vulnerability scanning
- **Pre-commit**: Runs pre-commit hooks in CI

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers:** Tags starting with `v*`, Manual dispatch

**Jobs:**

- **Release**: Builds all platforms, creates GitHub release
- **Publish Android**: Publishes to Google Play Console (if configured)
- **Deploy Web**: Deploys to GitHub Pages

### 3. Dependabot Auto-merge (`.github/workflows/dependabot-auto-merge.yml`)

**Triggers:** Dependabot PRs

**Function:** Auto-merges patch and minor version updates

## 🔧 Configuration Files

### `.github/dependabot.yml`

- Weekly dependency updates
- Dart/Flutter and GitHub Actions ecosystems
- Auto-assignment and labeling

### `.secrets.baseline`

- Baseline for secret detection
- Prevents false positives in security scans

## 🛠️ Development Workflow

### Daily Development

1. **Before committing**: Pre-commit hooks run automatically
2. **On push/PR**: GitHub Actions CI runs
3. **Weekly**: Dependabot checks for updates

### Release Process

1. **Create tag**: `git tag v1.0.0 && git push origin v1.0.0`
2. **Automatic**: Release workflow builds and publishes
3. **Manual**: Use GitHub UI for manual releases

## 🔍 Troubleshooting

### Pre-commit Issues

```bash
# Update hooks
pre-commit autoupdate

# Run specific hook
pre-commit run dart-format --all-files

# Skip hooks (emergency only)
git commit --no-verify
```

### CI Issues

```bash
# Run tests locally
flutter test --coverage

# Run analysis
flutter analyze

# Check formatting
dart format --output=none --set-exit-if-changed .

# Reproduce the web build CI gate
flutter build web --release
```

### iOS release build (local only — not run in CI)

CI does not exercise iOS or run macOS runners. Verify release-mode signing and archive locally before tagging:

```bash
# Release-mode device build with the project's automatic signing.
flutter build ios --release

# Produce a development-signed .ipa for sideload / TestFlight upload.
flutter build ipa --release --export-method development
# Output: build/ios/ipa/*.ipa, archive at build/ios/archive/Runner.xcarchive
```

The bundle identifier is `com.example.howardism` (the `com.example.` prefix is a Flutter scaffold leftover and should be replaced with a real reverse-DNS prefix before App Store submission). Code signing uses the Apple Developer team configured in `ios/Runner.xcodeproj` (Automatic signing, team `9KRJ83FMAF`).

### Brand assets — regenerate

Sources live in `assets/brand/*.svg`. To regenerate after editing them:

```bash
brew install librsvg                       # one-time
./scripts/build-brand-pngs.sh              # SVG -> PNG sources
dart run flutter_launcher_icons            # iOS + web icons
dart run flutter_native_splash:create      # iOS + web splash
```

### Common Problems

1. **Flutter not found**: Ensure Flutter is in PATH
2. **Python issues**: Use `python3` and `pip3`
3. **Permission denied**: Run `chmod +x setup-precommit.sh`
4. **Hook failures**: Check Flutter installation with `flutter doctor`

## 📊 Monitoring

### Code Quality

- **Coverage**: Codecov integration
- **Analysis**: Flutter analyze results
- **Security**: Trivy scan results

### Dependencies

- **Updates**: Dependabot PRs
- **Vulnerabilities**: Security alerts
- **Licenses**: License compliance

## 🔐 Security

### Secrets Management

- Use GitHub Secrets for sensitive data
- Never commit API keys or tokens
- Regular security scans with Trivy

### Required Secrets (Optional)

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: For Android publishing
- `CODECOV_TOKEN`: For coverage reporting

## 📈 Best Practices

### Commits

- Use Conventional Commits format
- Keep commits atomic and focused
- Write clear commit messages

### Pull Requests

- Ensure CI passes before merging
- Request reviews for significant changes
- Use descriptive PR titles and descriptions

### Releases

- Follow semantic versioning
- Create release notes
- Test thoroughly before releasing

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Ensure all dependencies are installed
4. Verify Flutter setup with `flutter doctor`

For additional help, refer to:

- [Pre-commit documentation](https://pre-commit.com/)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD guide](https://docs.flutter.dev/deployment/ci)
