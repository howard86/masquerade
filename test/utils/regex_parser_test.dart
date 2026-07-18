import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/regex_parser.dart';

void main() {
  group('RegexTester', () {
    test('returns matches and numbered captures', () {
      final RegexOk result =
          RegexTester.run(pattern: r'(\d+)', input: 'a12b34') as RegexOk;

      expect(result.matches, hasLength(2));
      expect(result.matches.first.text, '12');
      expect(result.matches.first.groups, <String?>['12']);
      expect(result.matches.last.text, '34');
      expect(result.truncated, isFalse);
    });

    test('pathological matching times out off the caller isolate', () async {
      bool started = false;
      final RegexResult result = await RegexTester.runAsync(
        pattern: r'(a+)+$',
        input: '${'a' * 10000}!',
        timeLimit: Duration.zero,
        onWorkerStarted: () => started = true,
      );

      expect(started, isTrue);
      expect(result, isA<RegexErr>());
      expect((result as RegexErr).message, contains('timed out'));
    });

    test('worker setup failure returns a bounded error', () async {
      final RegexResult result = await RegexTester.runAsync(
        pattern: '.',
        input: 'x',
        workerRunner:
            ({
              required String pattern,
              required String input,
              required bool caseSensitive,
              required bool multiLine,
              required bool dotAll,
              required bool unicode,
              required Duration timeLimit,
              void Function()? onStarted,
            }) async => throw StateError('worker blocked by policy'),
      );

      expect(result, isA<RegexErr>());
      expect(
        (result as RegexErr).message,
        'Regular expression matching is unavailable.',
      );
      expect(result.message, isNot(contains('worker blocked')));
    });

    test('async worker preserves UTF-16 offsets and named captures', () async {
      final RegexOk result =
          await RegexTester.runAsync(
                pattern: r'(?<emoji>.)',
                input: '😀',
                unicode: true,
              )
              as RegexOk;

      expect(result.matches.single.start, 0);
      expect(result.matches.single.end, 2);
      expect(result.matches.single.text, '😀');
      expect(result.matches.single.groups, <String?>['😀']);
      expect(result.matches.single.named, <String, String?>{'emoji': '😀'});

      final RegexOk empty =
          await RegexTester.runAsync(pattern: '', input: '😀', unicode: true)
              as RegexOk;
      expect(empty.matches.map((RegexMatchInfo match) => match.start), <int>[
        0,
        2,
      ]);

      final RegexErr captures =
          await RegexTester.runAsync(
                pattern: List<String>.filled(101, '(a)').join(),
                input: '',
              )
              as RegexErr;
      expect(captures.message, 'Pattern is limited to 100 capture groups.');
    });

    test('returns named and optional captures', () {
      final RegexOk result =
          RegexTester.run(
                pattern: r'(?<year>\d{4})(?:-(?<month>\d{2}))?',
                input: '2026',
              )
              as RegexOk;

      expect(result.matches.single.named, <String, String?>{
        'year': '2026',
        'month': null,
      });
      expect(result.matches.single.groups, <String?>['2026', null]);
    });

    test('invalid pattern returns a bounded error instead of throwing', () {
      final RegexResult result = RegexTester.run(pattern: '(', input: 'x');
      final RegexErr secret =
          RegexTester.run(pattern: '(do-not-echo', input: 'x') as RegexErr;

      expect(result, isA<RegexErr>());
      expect((result as RegexErr).message, isNotEmpty);
      expect(result.message.length, lessThan(200));
      expect(secret.message, isNot(contains('do-not-echo')));
    });

    test('supports case-sensitive, multi-line, and dot-all flags', () {
      expect(
        (RegexTester.run(pattern: 'A', input: 'a', caseSensitive: false)
                as RegexOk)
            .matches,
        hasLength(1),
      );
      expect(
        (RegexTester.run(pattern: r'^x', input: 'foo\nxbar', multiLine: true)
                as RegexOk)
            .matches
            .single
            .start,
        4,
      );
      expect(
        (RegexTester.run(pattern: r'a.b', input: 'a\nb', dotAll: true)
                as RegexOk)
            .matches,
        hasLength(1),
      );
    });

    test('unicode mode preserves UTF-16 offsets and complete emoji', () {
      final RegexOk unicode =
          RegexTester.run(pattern: '.', input: '😀') as RegexOk;
      final RegexOk codeUnits =
          RegexTester.run(pattern: '.', input: '😀', unicode: false) as RegexOk;

      expect(unicode.matches.single.text, '😀');
      expect(unicode.matches.single.start, 0);
      expect(unicode.matches.single.end, 2);
      expect(codeUnits.matches, hasLength(2));
    });

    test('empty pattern includes terminal zero-width match', () {
      final RegexOk result =
          RegexTester.run(pattern: '', input: 'ab') as RegexOk;

      expect(result.matches.map((RegexMatchInfo match) => match.start), <int>[
        0,
        1,
        2,
      ]);
      expect(
        result.matches.every((RegexMatchInfo match) => match.text.isEmpty),
        isTrue,
      );
    });

    test('caps matches and reports truncation exactly', () {
      final RegexOk exact =
          RegexTester.run(pattern: 'x', input: 'x' * RegexTester.maxMatches)
              as RegexOk;
      final RegexOk overflow =
          RegexTester.run(pattern: '', input: 'x' * RegexTester.maxMatches)
              as RegexOk;

      expect(exact.matches, hasLength(RegexTester.maxMatches));
      expect(exact.truncated, isFalse);
      expect(overflow.matches, hasLength(RegexTester.maxMatches));
      expect(overflow.truncated, isTrue);
    });

    test('standard matching does not produce overlapping results', () {
      final RegexOk result =
          RegexTester.run(pattern: 'aba', input: 'ababa') as RegexOk;

      expect(result.matches.map((RegexMatchInfo match) => match.start), <int>[
        0,
      ]);
    });

    test('capture group cap applies even without a match', () {
      final RegexResult result = RegexTester.run(
        pattern: List<String>.filled(101, '(a)').join(),
        input: '',
      );

      expect(result, isA<RegexErr>());
      expect((result as RegexErr).message, contains('100 capture groups'));
    });

    test('rejects oversized inputs without echoing their contents', () {
      const String secret = 'do-not-echo';
      final RegexErr pattern =
          RegexTester.run(pattern: secret * 500, input: '') as RegexErr;
      final RegexErr input =
          RegexTester.run(pattern: '.', input: secret * 7000) as RegexErr;

      expect(pattern.message, isNot(contains(secret)));
      expect(input.message, isNot(contains(secret)));
    });
  });
}
