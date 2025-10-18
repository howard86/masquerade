# Flutter Rules Testing Guide

This guide provides step-by-step instructions for testing your Flutter Cursor rules to ensure they're working correctly.

## 🚀 Quick Start

### 1. Run the Validation Scripts

```bash
# Make scripts executable (if not already done)
chmod +x scripts/test_flutter_rules.sh
chmod +x scripts/validate_flutter_rules.dart

# Run the validation script
dart run scripts/validate_flutter_rules.dart

# Or run the bash script
./scripts/test_flutter_rules.sh
```

### 2. Check the Test Report

The validation script generates a test report at `flutter_rules_test_report.json` with detailed information about your rules.

## 📋 Testing Methods

### Method 1: Automated Validation

The validation scripts automatically check:

- ✅ Rule file structure and frontmatter
- ✅ Content quality and length
- ✅ Code examples presence
- ✅ Flutter/Dart content
- ✅ File pattern coverage

### Method 2: Manual Testing in Cursor

1. **Open Cursor IDE**
2. **Create test files** with patterns that should trigger rules
3. **Ask AI to generate code** related to those files
4. **Verify the generated code** follows your rules

### Method 3: Interactive Testing

1. **Create test scenarios** for each rule type
2. **Test rule activation** by opening relevant files
3. **Verify rule effectiveness** by asking AI questions
4. **Check rule consistency** across different scenarios

## 🧪 Test Scenarios

### Scenario 1: Multi-Platform Rules Testing

**Test File**: `lib/main.dart`
**Expected Behavior**: Rules should activate and provide multi-platform guidance

```dart
// Test prompt: "Create a responsive widget that works on web, iOS, and Android"
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 900) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
```

### Scenario 2: Web Rules Testing

**Test File**: `lib/platform/web/web_service.dart`
**Expected Behavior**: Rules should activate and provide web-specific guidance

```dart
// Test prompt: "Add PWA features to this web service"
import 'package:flutter/material.dart';

class WebService {
  static String getPlatformName() {
    return 'Web';
  }

  static void handleWebSpecificFeature() {
    // Web-specific implementation
  }

  static void enablePWAFeatures() {
    // PWA implementation
  }
}
```

### Scenario 3: Architecture Rules Testing

**Test File**: `lib/features/user/domain/entities/user.dart`
**Expected Behavior**: Rules should activate and provide architecture guidance

```dart
// Test prompt: "Add error handling to this user entity"
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
```

### Scenario 4: Testing Rules Testing

**Test File**: `test/unit/user_test.dart`
**Expected Behavior**: Rules should activate and provide testing guidance

```dart
// Test prompt: "Add more test cases for this user entity"
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
```

### Scenario 5: Deployment Rules Testing

**Test File**: `.github/workflows/ci_cd.yml`
**Expected Behavior**: Rules should activate and provide deployment guidance

```yaml
# Test prompt: "Add iOS and Android deployment to this CI/CD pipeline"
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
          flutter-version: "3.16.0"
          channel: "stable"

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test
```

## 🔍 Testing Checklist

### Pre-Testing Setup

- [ ] Run validation scripts
- [ ] Check test report
- [ ] Create test files if missing
- [ ] Open Cursor IDE

### Rule Activation Testing

- [ ] Test multi-platform rules with `lib/main.dart`
- [ ] Test web rules with `lib/platform/web/web_service.dart`
- [ ] Test iOS rules with `lib/platform/ios/ios_service.dart`
- [ ] Test Android rules with `lib/platform/android/android_service.dart`
- [ ] Test architecture rules with `lib/core/errors/exceptions.dart`
- [ ] Test testing rules with `test/unit/user_test.dart`
- [ ] Test deployment rules with `.github/workflows/ci_cd.yml`

### Rule Effectiveness Testing

- [ ] Ask AI to generate responsive widgets
- [ ] Ask AI to add PWA features
- [ ] Ask AI to implement clean architecture
- [ ] Ask AI to create comprehensive tests
- [ ] Ask AI to set up CI/CD pipelines
- [ ] Verify generated code follows rules

### Quality Assurance

- [ ] Check rule consistency
- [ ] Verify no rule conflicts
- [ ] Test rule completeness
- [ ] Validate rule accuracy
- [ ] Test rule helpfulness

## 🎯 Expected Results

### Successful Rule Testing Should Show:

1. **Rule Activation**: Rules activate for correct file patterns
2. **Content Quality**: Rules provide helpful, accurate guidance
3. **Code Examples**: Rules include relevant code examples
4. **Consistency**: Rules are consistent across different scenarios
5. **Completeness**: Rules cover all necessary aspects
6. **Effectiveness**: AI generates code that follows the rules

### Common Issues and Solutions:

1. **Rules Not Activating**: Check glob patterns and file paths
2. **Poor Code Quality**: Review rule content and examples
3. **Rule Conflicts**: Ensure rules don't contradict each other
4. **Incomplete Coverage**: Add missing scenarios to rules
5. **Ineffective Guidance**: Update rule content based on testing

## 📊 Monitoring and Maintenance

### Regular Testing Schedule:

- **Weekly**: Run validation scripts
- **Monthly**: Test rule effectiveness
- **Quarterly**: Review and update rules
- **As Needed**: Test new rule additions

### Key Metrics to Track:

- Rule activation rate
- Code quality improvement
- Developer satisfaction
- Rule effectiveness scores
- Coverage completeness

## 🚨 Troubleshooting

### If Rules Aren't Working:

1. **Check File Patterns**: Ensure glob patterns match your file structure
2. **Verify Frontmatter**: Check that frontmatter is properly formatted
3. **Test Rule Content**: Ensure rule content is relevant and helpful
4. **Check Cursor Settings**: Verify Cursor is using the rules
5. **Restart Cursor**: Sometimes Cursor needs a restart to pick up new rules

### If AI Isn't Following Rules:

1. **Check Rule Activation**: Ensure rules are activating for the right files
2. **Review Rule Content**: Make sure rules are clear and actionable
3. **Test with Different Prompts**: Try various prompts to test rule effectiveness
4. **Update Rule Examples**: Add more relevant code examples
5. **Check Rule Conflicts**: Ensure rules don't contradict each other

This comprehensive testing guide ensures your Flutter Cursor rules are working correctly and providing valuable guidance for your development workflow.
