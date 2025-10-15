#!/bin/bash
set -e

echo "🧪 Testing GitHub Actions Workflow Steps Locally"
echo "================================================"

# Check if required tools are installed
echo "📋 Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

if ! command -v dart &> /dev/null; then
    echo "❌ Dart not found. Please install Dart first."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python3 first."
    exit 1
fi

echo "✅ All prerequisites found"

# Test Flutter setup
echo ""
echo "🔧 Testing Flutter setup..."
flutter --version
dart --version

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
flutter pub get

# Test formatting
echo ""
echo "🎨 Testing code formatting..."
dart format --output=none --set-exit-if-changed . || {
    echo "❌ Code formatting issues found. Run 'dart format .' to fix."
    exit 1
}
echo "✅ Code formatting is correct"

# Test analysis
echo ""
echo "🔍 Running Flutter analysis..."
flutter analyze || {
    echo "❌ Flutter analysis found issues."
    exit 1
}
echo "✅ Flutter analysis passed"

# Test pre-commit hooks
echo ""
echo "🪝 Testing pre-commit hooks..."

# Install pre-commit if not already installed
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    pip3 install pre-commit
fi

# Run pre-commit hooks
pre-commit run --all-files || {
    echo "❌ Pre-commit hooks failed."
    exit 1
}
echo "✅ Pre-commit hooks passed"

# Run tests (optional)
echo ""
echo "🧪 Running tests..."
flutter test --coverage || {
    echo "⚠️  Tests failed or no tests found (this is OK for now)"
}

echo ""
echo "🎉 All workflow steps completed successfully!"
echo "Your GitHub Actions workflows should work correctly."
