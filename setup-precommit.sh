#!/bin/bash

# Setup script for pre-commit hooks in Flutter project
# This script installs and configures pre-commit hooks

set -e

echo "🚀 Setting up pre-commit hooks for Flutter project..."

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ This script must be run from within a Git repository."
    echo "   Please run 'git init' first or navigate to a Git repository."
    exit 1
fi

echo "✅ Git repository detected"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed. Please install Python 3 first."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed. Please install pip3 first."
    exit 1
fi

# Check if Flutter is installed
if command -v flutter &> /dev/null; then
    echo "✅ Flutter is already installed"
    flutter --version | head -1
else
    echo "⚠️  Flutter is not installed or not in PATH"
    echo "   Please install Flutter from https://flutter.dev/docs/get-started/install"
    echo "   Continuing with pre-commit setup..."
fi

# Check if Dart is installed
if command -v dart &> /dev/null; then
    echo "✅ Dart is already installed"
    dart --version | head -1
else
    echo "⚠️  Dart is not installed or not in PATH"
    echo "   Dart usually comes with Flutter installation"
    echo "   Continuing with pre-commit setup..."
fi

# Check if pre-commit is already installed
if command -v pre-commit &> /dev/null; then
    echo "✅ Pre-commit is already installed"
    pre-commit --version
else
    echo "📦 Installing pre-commit..."
    pip3 install pre-commit
fi

# Check if pre-commit hooks are already installed
if [ -f .git/hooks/pre-commit ]; then
    echo "✅ Pre-commit hooks are already installed"
else
    echo "🔧 Installing pre-commit hooks..."
    pre-commit install
fi

# Check if commit-msg hooks are already installed
if [ -f .git/hooks/commit-msg ]; then
    echo "✅ Commit-msg hooks are already installed"
else
    echo "🔧 Installing additional hooks..."
    pre-commit install --hook-type commit-msg
fi

# Check if .pre-commit-config.yaml exists
if [ -f .pre-commit-config.yaml ]; then
    echo "✅ Pre-commit configuration file found"
else
    echo "❌ .pre-commit-config.yaml not found in current directory"
    echo "   Please ensure you're running this script from the project root"
    exit 1
fi

# Run pre-commit on all files to set up the environment
echo "🧹 Running pre-commit on all files (this may take a while)..."
pre-commit run --all-files || true

# Update secrets baseline
echo "🔒 Updating secrets baseline..."
pre-commit run detect-secrets --all-files || true

echo ""
echo "✅ Pre-commit setup complete!"
echo ""
echo "📊 Setup Summary:"
echo "=================="
if command -v pre-commit &> /dev/null; then
    echo "✅ Pre-commit: $(pre-commit --version | head -1)"
else
    echo "❌ Pre-commit: Not installed"
fi

if [ -f .git/hooks/pre-commit ]; then
    echo "✅ Pre-commit hooks: Installed"
else
    echo "❌ Pre-commit hooks: Not installed"
fi

if [ -f .git/hooks/commit-msg ]; then
    echo "✅ Commit-msg hooks: Installed"
else
    echo "❌ Commit-msg hooks: Not installed"
fi

if command -v flutter &> /dev/null; then
    echo "✅ Flutter: $(flutter --version | head -1)"
else
    echo "⚠️  Flutter: Not found in PATH"
fi

if command -v dart &> /dev/null; then
    echo "✅ Dart: $(dart --version | head -1)"
else
    echo "⚠️  Dart: Not found in PATH"
fi

echo ""
echo "📋 Next steps:"
echo "1. Run 'flutter pub get' to install dependencies"
echo "2. Run 'flutter doctor' to verify your Flutter setup"
echo "3. Commit your changes to test the pre-commit hooks"
echo ""
echo "🔧 Useful commands:"
echo "- Run pre-commit on all files: pre-commit run --all-files"
echo "- Update hooks: pre-commit autoupdate"
echo "- Skip hooks for a commit: git commit --no-verify"
echo "- Check hook status: pre-commit --version"
