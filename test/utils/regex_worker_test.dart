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

  group('RegexWorkerSession (native)', () {
    Future<RegexResult> run(
      RegexWorkerSession session,
      String pattern,
      String input, {
      Duration timeLimit = const Duration(seconds: 5),
    }) => session.run(
      pattern: pattern,
      input: input,
      caseSensitive: true,
      multiLine: false,
      dotAll: false,
      unicode: true,
      timeLimit: timeLimit,
    );

    // ~2^28 backtracking steps: seconds of CPU unless the isolate is killed.
    final String catastrophic = '${'a' * 28}!';

    test('reuses one isolate across sequential runs', () async {
      final RegexWorkerSession session = RegexWorkerSession();
      addTearDown(session.dispose);
      for (int i = 0; i < 5; i++) {
        final RegexResult result = await run(session, r'(\d+)', 'a$i b');
        expect((result as RegexOk).matches.single.text, '$i');
        expect(session.liveWorkers, 1);
      }
      expect(await run(session, '(', 'x'), isA<RegexErr>());
    });

    test('a new run kills a still-busy older run', () async {
      final RegexWorkerSession session = RegexWorkerSession();
      addTearDown(session.dispose);
      final List<Future<RegexResult>> stale = <Future<RegexResult>>[
        for (int i = 0; i < 4; i++) run(session, r'(a+)+$', catastrophic),
      ];
      final Stopwatch sw = Stopwatch()..start();
      final RegexResult latest = await run(session, r'\d+', 'abc 123');
      sw.stop();

      expect((latest as RegexOk).matches.single.text, '123');
      for (final Future<RegexResult> future in stale) {
        expect(await future, same(RegexWorkerSession.superseded));
      }
      expect(session.liveWorkers, 1);
      // Well under the catastrophic run's multi-second duration.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('timeout kills the isolate; the next run respawns it', () async {
      final RegexWorkerSession session = RegexWorkerSession();
      addTearDown(session.dispose);
      bool started = false;
      final RegexResult timedOut = await session.run(
        pattern: r'(a+)+$',
        input: catastrophic,
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
        unicode: true,
        timeLimit: const Duration(milliseconds: 100),
        onStarted: () => started = true,
      );
      expect(started, isTrue);
      expect((timedOut as RegexErr).message, contains('timed out'));
      expect(session.liveWorkers, 0);

      final RegexResult next = await run(session, r'\d', 'x7');
      expect((next as RegexOk).matches.single.text, '7');
      expect(session.liveWorkers, 1);
    });

    test('dispose completes an in-flight run and kills the isolate', () async {
      final RegexWorkerSession session = RegexWorkerSession();
      final Future<RegexResult> pending = run(session, r'(a+)+$', catastrophic);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      session.dispose();
      expect(await pending, same(RegexWorkerSession.superseded));
      expect(session.liveWorkers, 0);
      expect(
        await run(session, r'\d', '1'),
        same(RegexWorkerSession.superseded),
      );
    });
  });
}
