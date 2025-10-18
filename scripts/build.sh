#!/bin/bash

# Build script for Flutter Multi-Platform App
# This file should trigger deployment-specific Flutter rules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Parse command line arguments
PLATFORM=$1
ENVIRONMENT=$2

if [ -z "$PLATFORM" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <platform> <environment>"
    echo "Platforms: web, android, ios, all"
    echo "Environments: dev, staging, prod"
    exit 1
fi

print_status "info" "Starting Flutter build for $PLATFORM ($ENVIRONMENT)"

# Set environment variables
export ENVIRONMENT=$ENVIRONMENT

# Install dependencies
print_status "info" "Installing dependencies..."
flutter pub get

# Run tests
print_status "info" "Running tests..."
flutter test

# Build based on platform
case $PLATFORM in
    web)
        print_status "info" "Building for web..."
        flutter build web --release
        print_status "success" "Web build completed"
        ;;
    android)
        print_status "info" "Building for Android..."
        flutter build apk --release
        flutter build appbundle --release
        print_status "success" "Android build completed"
        ;;
    ios)
        print_status "info" "Building for iOS..."
        flutter build ios --release --no-codesign
        print_status "success" "iOS build completed"
        ;;
    all)
        print_status "info" "Building for all platforms..."

        # Web
        print_status "info" "Building for web..."
        flutter build web --release

        # Android
        print_status "info" "Building for Android..."
        flutter build apk --release
        flutter build appbundle --release

        # iOS
        print_status "info" "Building for iOS..."
        flutter build ios --release --no-codesign

        print_status "success" "All platform builds completed"
        ;;
    *)
        print_status "error" "Invalid platform: $PLATFORM"
        exit 1
        ;;
esac

print_status "success" "Build completed successfully!"
