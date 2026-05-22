import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/utility_catalog.dart';

void main() {
  group('UtilityCatalog.detectAll — shape detection', () {
    test('empty input returns empty', () {
      expect(UtilityCatalog.detectAll(''), isEmpty);
      expect(UtilityCatalog.detectAll('   '), isEmpty);
    });

    test('unix timestamp value surfaces Timestamp via shape', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(
        '1714972800',
      );
      expect(matches.map((UtilityDescriptor u) => u.id), contains('timestamp'));
    });

    test('hex color surfaces Color via shape', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(
        '#1F4FB8',
      );
      expect(matches.any((UtilityDescriptor u) => u.id == 'color'), isTrue);
    });
  });

  group('UtilityCatalog.detectAll — synonym fallthrough', () {
    test('"unix" surfaces Timestamp', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll('unix');
      expect(matches, isNotEmpty);
      expect(matches.first.id, 'timestamp');
    });

    test('"minify" surfaces JSON', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(
        'minify',
      );
      expect(matches, isNotEmpty);
      expect(matches.first.id, 'json');
    });

    test('"crontab" surfaces Cron', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(
        'crontab',
      );
      expect(matches, isNotEmpty);
      expect(matches.first.id, 'cron');
    });

    test('exact tool name wins over substring synonym', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll('color');
      expect(matches.first.id, 'color');
    });

    test('case-insensitive synonym match', () {
      final List<UtilityDescriptor> matches = UtilityCatalog.detectAll('UNIX');
      expect(matches.first.id, 'timestamp');
    });

    test('long noisy query returns empty (not a query shape)', () {
      expect(
        UtilityCatalog.detectAll(
          'this is way too long to be a tool query string',
        ),
        isEmpty,
      );
    });

    test('punctuation-heavy query returns empty', () {
      expect(UtilityCatalog.detectAll('foo!@#bar'), isEmpty);
    });

    test('unknown word returns empty', () {
      expect(UtilityCatalog.detectAll('xyzpdq'), isEmpty);
    });
  });

  group('README coverage — drift guard', () {
    test('toolbox section names every catalog tool', () {
      final String readme = File('README.md').readAsStringSync();

      const String heading = 'in the toolbox today';
      final int start = readme.indexOf(heading);
      expect(
        start,
        isNonNegative,
        reason: 'README is missing the "$heading" section.',
      );

      // Scope the check to that section (up to the next "## " heading).
      final int next = readme.indexOf('\n## ', start);
      final String section = next == -1
          ? readme.substring(start)
          : readme.substring(start, next);

      final List<String> missing = <String>[
        for (final UtilityDescriptor u in UtilityCatalog.all)
          if (!section.contains(u.name)) u.name,
      ];

      expect(
        missing,
        isEmpty,
        reason:
            'README "toolbox today" section is missing: ${missing.join(', ')}. '
            'Add a bullet naming each (see lib/utility_catalog.dart).',
      );
    });
  });
}
