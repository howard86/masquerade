# GitHub Actions Local Testing Guide

This guide explains how to test GitHub Actions workflows locally using various tools and methods.

## Tools for Local Testing

### 1. act - Run GitHub Actions Locally

`act` is the most popular tool for running GitHub Actions locally using Docker.

#### Installation

```bash
# Using curl (Linux/macOS)
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Using package managers
# Ubuntu/Debian
sudo apt install act

# macOS with Homebrew
brew install act

# Windows with Chocolatey
choco install act-cli
```

#### Configuration

Create `~/.config/act/actrc` with runner images:

```ini
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
-P ubuntu-20.04=catthehacker/ubuntu:act-20.04
-P ubuntu-18.04=catthehacker/ubuntu:act-18.04
-P windows-latest=catthehacker/ubuntu:act-latest
-P windows-2019=catthehacker/ubuntu:act-latest
-P macos-latest=catthehacker/ubuntu:act-latest
-P macos-12=catthehacker/ubuntu:act-latest
-P macos-11=catthehacker/ubuntu:act-latest
-P macos-10.15=catthehacker/ubuntu:act-latest
```

#### Basic Usage

```bash
# List all workflows and jobs
act --list

# Run a specific workflow
act -W .github/workflows/ci.yml

# Run a specific job
act -W .github/workflows/ci.yml -j pre-commit

# Dry run (simulate without executing)
act -W .github/workflows/ci.yml -j pre-commit --dryrun

# Run with specific event
act push

# Run with secrets
act -s SECRET_NAME=secret_value
```

#### Common Commands for This Project

```bash
# Test pre-commit job
act -W .github/workflows/ci.yml -j pre-commit --dryrun

# Test test job
act -W .github/workflows/ci.yml -j test --dryrun

# Test build job
act -W .github/workflows/ci.yml -j build --dryrun

# Test security job
act -W .github/workflows/ci.yml -j security --dryrun
```

### 2. Docker-Based Testing

You can also create custom Docker containers to test specific parts of your workflow.

#### Create a Flutter Testing Container

```dockerfile
# Dockerfile.flutter-test
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk \
    python3 \
    python3-pip

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Install pre-commit
RUN pip3 install pre-commit

WORKDIR /workspace
COPY . .

# Install dependencies
RUN flutter pub get

CMD ["flutter", "test"]
```

#### Build and Run

```bash
# Build the container
docker build -f Dockerfile.flutter-test -t flutter-test .

# Run tests
docker run --rm -v $(pwd):/workspace flutter-test

# Run specific commands
docker run --rm -v $(pwd):/workspace flutter-test flutter analyze
docker run --rm -v $(pwd):/workspace flutter-test dart format --set-exit-if-changed .
```

### 3. Manual Testing Scripts

Create shell scripts to test individual workflow steps locally.

#### test-pre-commit.sh

```bash
#!/bin/bash
set -e

echo "Testing pre-commit workflow steps..."

# Setup Java
echo "Setting up Java..."
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Setup Flutter
echo "Setting up Flutter..."
export PATH="$PATH:/opt/flutter/bin"

# Install dependencies
echo "Installing dependencies..."
flutter pub get

# Install pre-commit
echo "Installing pre-commit..."
pip3 install pre-commit

# Run pre-commit hooks
echo "Running pre-commit hooks..."
pre-commit run --all-files

echo "Pre-commit test completed successfully!"
```

## Current Project Status

### ✅ Working Workflows

- **CI Workflow** (`ci.yml`): All jobs can be tested with `act`
  - `pre-commit`: ✅ Fixed and working
  - `test`: ✅ Working
  - `build`: ✅ Working
  - `security`: ✅ Working

### ⚠️ Known Issues

- **Release Workflow** (`release.yml`): Has YAML validation issues with `act`
  - The workflow is syntactically valid YAML
  - `act` seems to have issues with certain GitHub Actions features
  - This is likely a limitation of `act` rather than the workflow itself

### 🔧 Fixed Issues

1. **Pre-commit job missing Flutter setup**: Fixed by adding Java and Flutter setup steps
2. **YAML indentation issues**: Fixed inconsistent indentation in release workflow

## Testing Commands

### Quick Test Commands

```bash
# Test all CI jobs (dry run)
act -W .github/workflows/ci.yml --dryrun

# Test specific job
act -W .github/workflows/ci.yml -j pre-commit --dryrun

# Test with actual execution (be careful!)
act -W .github/workflows/ci.yml -j pre-commit
```

### Manual Testing

```bash
# Test Flutter setup
flutter --version
dart --version

# Test pre-commit hooks
pre-commit run --all-files

# Test Flutter commands
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

## Troubleshooting

### Common Issues

1. **Docker not running**: Ensure Docker daemon is running
2. **Permission issues**: Run with appropriate permissions
3. **Network issues**: Check internet connection for downloading actions
4. **Image pull failures**: Try different runner images

### Debug Commands

```bash
# Check act version
act --version

# List available workflows
act --list

# Verbose output
act -v

# Check Docker
docker --version
docker ps
```

## Best Practices

1. **Always use `--dryrun` first** to test workflow structure
2. **Test individual jobs** before running entire workflows
3. **Use secrets carefully** - never commit real secrets
4. **Keep Docker images updated** for better compatibility
5. **Test on multiple platforms** when possible

## Alternative Tools

- **nektos/act**: Primary tool for local GitHub Actions testing
- **Custom Docker containers**: For specific testing scenarios
- **GitHub Codespaces**: Cloud-based testing environment
- **Local CI runners**: Self-hosted runners for testing
