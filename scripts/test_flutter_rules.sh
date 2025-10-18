#!/bin/bash

# Flutter Rules Testing Script
# This script helps test if your Flutter Cursor rules are working correctly

set -e

echo "🧪 Flutter Rules Testing Script"
echo "================================"
echo ""

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

# Check if we're in a Flutter project
check_flutter_project() {
    if [ ! -f "pubspec.yaml" ]; then
        print_status "error" "Not in a Flutter project directory"
        print_status "info" "Please run this script from your Flutter project root"
        exit 1
    fi
    print_status "success" "Flutter project detected"
}

# Check if Cursor rules exist
check_cursor_rules() {
    if [ ! -d ".cursor/rules" ]; then
        print_status "error" "Cursor rules directory not found"
        print_status "info" "Please ensure .cursor/rules directory exists"
        exit 1
    fi

    local rule_count=$(find .cursor/rules -name "*.mdc" | wc -l)
    if [ $rule_count -eq 0 ]; then
        print_status "error" "No rule files found in .cursor/rules"
        exit 1
    fi

    print_status "success" "Found $rule_count rule files"
}

# Validate rule files
validate_rule_files() {
    echo ""
    echo "🔍 Validating Rule Files"
    echo "----------------------"

    for rule_file in .cursor/rules/*.mdc; do
        if [ -f "$rule_file" ]; then
            local filename=$(basename "$rule_file")
            echo "Checking $filename..."

            # Check if file has frontmatter
            if ! head -n 1 "$rule_file" | grep -q "---"; then
                print_status "error" "$filename: Missing frontmatter"
                continue
            fi

            # Check if file has closing frontmatter
            if ! grep -q "^---$" "$rule_file"; then
                print_status "error" "$filename: Missing closing frontmatter"
                continue
            fi

            # Check file size
            local file_size=$(wc -c < "$rule_file")
            if [ $file_size -lt 100 ]; then
                print_status "warning" "$filename: File seems too short ($file_size bytes)"
            else
                print_status "success" "$filename: Valid structure ($file_size bytes)"
            fi

            # Check for code examples
            if grep -q "```" "$rule_file"; then
                print_status "success" "$filename: Contains code examples"
            else
                print_status "warning" "$filename: No code examples found"
            fi
        fi
    done
}

# Test rule activation patterns
test_rule_patterns() {
    echo ""
    echo "🎯 Testing Rule Activation Patterns"
    echo "----------------------------------"

    # Test multi-platform rules
    if [ -f "lib/main.dart" ]; then
        print_status "success" "lib/main.dart exists - should trigger multi-platform rules"
    else
        print_status "warning" "lib/main.dart not found - create to test multi-platform rules"
    fi

    # Test web rules
    if [ -f "lib/platform/web/web_service.dart" ] || [ -f "web/index.html" ]; then
        print_status "success" "Web files exist - should trigger web rules"
    else
        print_status "warning" "No web files found - create to test web rules"
    fi

    # Test iOS rules
    if [ -f "lib/platform/ios/ios_service.dart" ] || [ -f "ios/Runner/Info.plist" ]; then
        print_status "success" "iOS files exist - should trigger iOS rules"
    else
        print_status "warning" "No iOS files found - create to test iOS rules"
    fi

    # Test Android rules
    if [ -f "lib/platform/android/android_service.dart" ] || [ -f "android/app/build.gradle" ]; then
        print_status "success" "Android files exist - should trigger Android rules"
    else
        print_status "warning" "No Android files found - create to test Android rules"
    fi

    # Test architecture rules
    if [ -f "lib/core/errors/exceptions.dart" ] || [ -f "lib/features/user/domain/entities/user.dart" ]; then
        print_status "success" "Architecture files exist - should trigger architecture rules"
    else
        print_status "warning" "No architecture files found - create to test architecture rules"
    fi

    # Test testing rules
    if [ -f "test/unit/user_test.dart" ] || [ -f "integration_test/app_test.dart" ]; then
        print_status "success" "Test files exist - should trigger testing rules"
    else
        print_status "warning" "No test files found - create to test testing rules"
    fi

    # Test deployment rules
    if [ -f ".github/workflows/ci_cd.yml" ] || [ -f "scripts/build.sh" ]; then
        print_status "success" "Deployment files exist - should trigger deployment rules"
    else
        print_status "warning" "No deployment files found - create to test deployment rules"
    fi
}

# Create test files for rule testing
create_test_files() {
    echo ""
    echo "📁 Creating Test Files for Rule Testing"
    echo "--------------------------------------"

    # Create directory structure
    mkdir -p lib/core/errors
    mkdir -p lib/features/user/domain/entities
    mkdir -p lib/platform/web
    mkdir -p lib/platform/ios
    mkdir -p lib/platform/android
    mkdir -p lib/shared/widgets
    mkdir -p test/unit
    mkdir -p integration_test
    mkdir -p scripts

    # Create test files
    cat > lib/core/errors/exceptions.dart << 'EOF'
// Test file for architecture rules
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.code]);
}

class ServerException extends AppException {
  const ServerException(super.message, [super.code]);
}
EOF

    cat > lib/features/user/domain/entities/user.dart << 'EOF'
// Test file for architecture rules
class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
EOF

    cat > lib/platform/web/web_service.dart << 'EOF'
// Test file for web rules
import 'package:flutter/material.dart';

class WebService {
  static String getPlatformName() {
    return 'Web';
  }

  static void handleWebSpecificFeature() {
    // Web-specific implementation
  }
}
EOF

    cat > test/unit/user_test.dart << 'EOF'
// Test file for testing rules
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/domain/entities/user.dart';

void main() {
  group('User Entity', () {
    test('should create a user with valid data', () {
      // Arrange
      const id = '123';
      const name = 'John Doe';
      const email = 'john@example.com';
      final createdAt = DateTime(2023, 1, 1);

      // Act
      final user = User(
        id: id,
        name: name,
        email: email,
        createdAt: createdAt,
      );

      // Assert
      expect(user.id, equals(id));
      expect(user.name, equals(name));
      expect(user.email, equals(email));
      expect(user.createdAt, equals(createdAt));
    });
  });
}
EOF

    cat > .github/workflows/ci_cd.yml << 'EOF'
# Test file for deployment rules
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test
EOF

    print_status "success" "Test files created successfully"
}

# Test rule effectiveness with AI
test_rule_effectiveness() {
    echo ""
    echo "🤖 Testing Rule Effectiveness"
    echo "----------------------------"
    echo ""
    echo "To test rule effectiveness:"
    echo "1. Open Cursor IDE"
    echo "2. Open one of the test files created above"
    echo "3. Ask AI to generate code related to that file type"
    echo "4. Verify that the generated code follows the rules"
    echo ""
    echo "Example prompts to test:"
    echo "  - 'Create a responsive widget for web'"
    echo "  - 'Add error handling to this user entity'"
    echo "  - 'Create a test for this user entity'"
    echo "  - 'Set up CI/CD pipeline for this Flutter app'"
    echo ""
    print_status "info" "Manual testing required - open Cursor IDE and test with AI"
}

# Main execution
main() {
    echo "Starting Flutter Rules Testing..."
    echo ""

    check_flutter_project
    check_cursor_rules
    validate_rule_files
    test_rule_patterns

    # Ask user if they want to create test files
    echo ""
    read -p "Do you want to create test files for rule testing? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_test_files
    fi

    test_rule_effectiveness

    echo ""
    echo "🎉 Flutter Rules Testing Complete!"
    echo "================================="
    echo ""
    echo "Next steps:"
    echo "1. Open Cursor IDE"
    echo "2. Open the test files created above"
    echo "3. Test rule activation and effectiveness"
    echo "4. Verify AI suggestions follow your rules"
    echo ""
    print_status "success" "Testing script completed successfully!"
}

# Run main function
main "$@"
