import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/regex_parser.dart';
import 'package:masquerade/utils/regex_worker_native.dart';

// Exercises regex_worker_native.dart directly (the isolate-based worker used
// by RegexTester.runAsync on native/VM targets). regex_worker_web.dart uses
// dart:js_interop and a browser Worker, which cannot run under `flutter test`
// (VM), so its logic is untested here — see PR follow-ups.
void main() {
  group('runRegexWorker (native)', () {
    test('valid pattern with groups extracts matches', () async {
      final RegexResult result = await runRegexWorker(
        pattern: r'(\d+)-(\d+)',
        input: 'a12-34b',
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
        unicode: true,
        timeLimit: const Duration(seconds: 5),
      );

      expect(result, isA<RegexOk>());
      final RegexOk ok = result as RegexOk;
      expect(ok.matches, hasLength(1));
      expect(ok.matches.single.text, '12-34');
      expect(ok.matches.single.groups, <String?>['12', '34']);
      expect(ok.truncated, isFalse);
    });

    test('invalid pattern surfaces an error without crashing', () async {
      final RegexResult result = await runRegexWorker(
        pattern: '(',
        input: 'x',
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
        unicode: true,
        timeLimit: const Duration(seconds: 5),
      );

      expect(result, isA<RegexErr>());
      expect((result as RegexErr).message, isNotEmpty);
    });

    test('empty input returns ok with no matches', () async {
      final RegexResult result = await runRegexWorker(
        pattern: r'\d+',
        input: '',
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
        unicode: true,
        timeLimit: const Duration(seconds: 5),
      );

      expect(result, isA<RegexOk>());
      expect((result as RegexOk).matches, isEmpty);
    });

    test(
      'kills the isolate and reports a timeout when the guard fires',
      () async {
        bool started = false;
        final RegexResult result = await runRegexWorker(
          pattern: r'(a+)+$',
          input: '${'a' * 10000}!',
          caseSensitive: true,
          multiLine: false,
          dotAll: false,
          unicode: true,
          timeLimit: Duration.zero,
          onStarted: () => started = true,
        );

        expect(started, isTrue);
        expect(result, isA<RegexErr>());
        expect((result as RegexErr).message, contains('timed out'));
      },
    );
  });
}
