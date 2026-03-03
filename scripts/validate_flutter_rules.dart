#!/usr/bin/env dart
// ignore_for_file: avoid_print
// Flutter Rules Validation Script
// This Dart script validates your Flutter Cursor rules

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  print('🔍 Flutter Rules Validation Script');
  print('==================================\n');

  try {
    await validateRules();
    await testRulePatterns();
    await generateTestReport();

    print('✅ All validations completed successfully!');
  } catch (e) {
    print('❌ Validation failed: $e');
    exit(1);
  }
}

Future<void> validateRules() async {
  print('📁 Validating Rule Files...\n');

  final rulesDir = Directory('.cursor/rules');
  if (!rulesDir.existsSync()) {
    throw Exception('Rules directory not found');
  }

  final ruleFiles = rulesDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.mdc'))
      .toList();

  if (ruleFiles.isEmpty) {
    throw Exception('No rule files found');
  }

  print('Found ${ruleFiles.length} rule files:');
  for (final file in ruleFiles) {
    print('  - ${file.path.split('/').last}');
  }
  print('');

  // Validate each rule file
  for (final ruleFile in ruleFiles) {
    await validateRuleFile(ruleFile);
  }
}

Future<void> validateRuleFile(File ruleFile) async {
  final fileName = ruleFile.path.split('/').last;
  print('🔍 Validating $fileName...');

  final content = await ruleFile.readAsString();
  final lines = content.split('\n');

  // Check for frontmatter
  if (!lines.first.startsWith('---')) {
    print('  ❌ Missing frontmatter');
    return;
  }

  // Check for closing frontmatter
  final frontmatterEnd = lines.indexOf('---', 1);
  if (frontmatterEnd == -1) {
    print('  ❌ Missing closing frontmatter');
    return;
  }

  // Parse frontmatter
  final frontmatter = lines.sublist(1, frontmatterEnd);
  final metadata = <String, dynamic>{};

  for (final line in frontmatter) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(':');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();
      metadata[key] = value;
    }
  }

  // Validate metadata
  if (metadata.containsKey('alwaysApply') &&
      metadata['alwaysApply'] == 'true') {
    print('  ✅ Always applied rule');
  } else if (metadata.containsKey('globs')) {
    print('  ✅ File-specific rule with globs: ${metadata['globs']}');
  } else if (metadata.containsKey('description')) {
    print('  ✅ Description-based rule: ${metadata['description']}');
  } else {
    print('  ⚠️  Rule without clear activation criteria');
  }

  // Check content quality
  final contentLines = lines.sublist(frontmatterEnd + 1);
  final contentText = contentLines.join('\n');

  if (contentText.length < 100) {
    print('  ⚠️  Rule content seems too short');
  } else {
    print('  ✅ Rule content length: ${contentText.length} characters');
  }

  // Check for code examples
  if (contentText.contains('```dart') || contentText.contains('```yaml')) {
    print('  ✅ Contains code examples');
  } else {
    print('  ⚠️  No code examples found');
  }

  // Check for Flutter-specific content
  if (contentText.toLowerCase().contains('flutter') ||
      contentText.toLowerCase().contains('dart')) {
    print('  ✅ Contains Flutter/Dart content');
  } else {
    print('  ⚠️  No Flutter/Dart content found');
  }

  print('  ✅ $fileName validation complete\n');
}

Future<void> testRulePatterns() async {
  print('🎯 Testing Rule Activation Patterns...\n');

  final testPatterns = [
    ('lib/main.dart', 'Multi-platform rules'),
    ('lib/platform/web/web_service.dart', 'Web rules'),
    ('lib/platform/ios/ios_service.dart', 'iOS rules'),
    ('lib/platform/android/android_service.dart', 'Android rules'),
    ('lib/core/errors/exceptions.dart', 'Architecture rules'),
    ('lib/features/user/domain/entities/user.dart', 'Architecture rules'),
    ('lib/shared/widgets/custom_button.dart', 'Architecture rules'),
    ('test/unit/user_test.dart', 'Testing rules'),
    ('integration_test/app_test.dart', 'Testing rules'),
    ('.github/workflows/ci_cd.yml', 'Deployment rules'),
    ('scripts/build.sh', 'Deployment rules'),
  ];

  for (final (filePath, ruleType) in testPatterns) {
    final file = File(filePath);
    if (file.existsSync()) {
      print('  ✅ $filePath exists - should trigger $ruleType');
    } else {
      print('  ⚠️  $filePath not found - create to test $ruleType');
    }
  }
  print('');
}

Future<void> generateTestReport() async {
  print('📊 Generating Test Report...\n');

  final report = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'rules_validation': await getRulesValidationReport(),
    'file_patterns': await getFilePatternsReport(),
    'recommendations': getRecommendations(),
  };

  final reportFile = File('flutter_rules_test_report.json');
  await reportFile.writeAsString(JsonEncoder.withIndent('  ').convert(report));

  print('  ✅ Test report generated: ${reportFile.path}');
  print('');

  // Print summary
  print('📋 Test Summary:');
  print('  - Rules validated: ${report['rules_validation']['total_rules']}');
  print(
    '  - File patterns tested: ${report['file_patterns']['total_patterns']}',
  );
  print('  - Recommendations: ${report['recommendations'].length}');
  print('');
}

Future<Map<String, dynamic>> getRulesValidationReport() async {
  final rulesDir = Directory('.cursor/rules');
  final ruleFiles = rulesDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.mdc'))
      .toList();

  return {
    'total_rules': ruleFiles.length,
    'rule_files': ruleFiles.map((f) => f.path.split('/').last).toList(),
    'validation_status': 'completed',
  };
}

Future<Map<String, dynamic>> getFilePatternsReport() async {
  final testPatterns = [
    'lib/main.dart',
    'lib/platform/web/web_service.dart',
    'lib/platform/ios/ios_service.dart',
    'lib/platform/android/android_service.dart',
    'lib/core/errors/exceptions.dart',
    'lib/features/user/domain/entities/user.dart',
    'lib/shared/widgets/custom_button.dart',
    'test/unit/user_test.dart',
    'integration_test/app_test.dart',
    '.github/workflows/ci_cd.yml',
    'scripts/build.sh',
  ];

  final existingFiles = <String>[];
  final missingFiles = <String>[];

  for (final pattern in testPatterns) {
    if (File(pattern).existsSync()) {
      existingFiles.add(pattern);
    } else {
      missingFiles.add(pattern);
    }
  }

  return {
    'total_patterns': testPatterns.length,
    'existing_files': existingFiles,
    'missing_files': missingFiles,
    'coverage_percentage': (existingFiles.length / testPatterns.length * 100)
        .round(),
  };
}

List<String> getRecommendations() {
  return [
    'Create test files for missing patterns to test rule activation',
    'Add more code examples to rules with insufficient examples',
    'Test rule effectiveness by asking AI to generate code',
    'Verify rules don\'t conflict with each other',
    'Update rules based on actual usage patterns',
    'Add platform-specific test cases',
    'Create integration tests for rule validation',
    'Monitor rule effectiveness over time',
  ];
}
