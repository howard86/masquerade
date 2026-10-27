@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/regex_parser.dart';
import 'package:masquerade/utils/regex_worker_web.dart';

// Browser-only: regex_worker_web.dart drives a real Web Worker, so this runs
// under `flutter test --platform chrome` and is skipped on the VM.
void main() {
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

  final String catastrophic = '${'a' * 30}!';

  test('reuses one Worker across sequential runs', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    for (int i = 0; i < 3; i++) {
      final RegexResult result = await run(session, r'(\d+)', 'a$i b');
      expect((result as RegexOk).matches.single.text, '$i');
      expect(session.liveWorkers, 1);
    }
    expect(await run(session, '(', 'x'), isA<RegexErr>());
  });

  test('a new run terminates a still-busy older run', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    final Future<RegexResult> stale = run(session, r'(a+)+$', catastrophic);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final RegexResult latest = await run(session, r'\d+', 'abc 123');
    expect((latest as RegexOk).matches.single.text, '123');
    expect(await stale, same(RegexWorkerSession.superseded));
    expect(session.liveWorkers, 1);
  });

  test('timeout terminates the Worker; the next run recreates it', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    final RegexResult timedOut = await run(
      session,
      r'(a+)+$',
      catastrophic,
      timeLimit: const Duration(milliseconds: 100),
    );
    expect((timedOut as RegexErr).message, contains('timed out'));
    expect(session.liveWorkers, 0);
    final RegexResult next = await run(session, r'\d', 'x7');
    expect((next as RegexOk).matches.single.text, '7');
  });

  test('one-shot runRegexWorker still works', () async {
    final RegexResult result = await runRegexWorker(
      pattern: r'(\d+)-(\d+)',
      input: 'a12-34b',
      caseSensitive: true,
      multiLine: false,
      dotAll: false,
      unicode: true,
      timeLimit: const Duration(seconds: 5),
    );
    expect((result as RegexOk).matches.single.groups, <String?>['12', '34']);
  });

  test('offset results: numbered, unmatched and named groups', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    final RegexOk result =
        await run(session, r'(?<k>\w+)=(\d+)?(x)?', 'a=1 b= c=3x') as RegexOk;
    expect(result.matches.map((RegexMatchInfo m) => m.text), <String>[
      'a=1',
      'b=',
      'c=3x',
    ]);
    expect(result.matches[1].start, 4);
    expect(result.matches[1].end, 6);
    expect(result.matches[0].groups, <String?>['a', '1', null]);
    expect(result.matches[1].groups, <String?>['b', null, null]);
    expect(result.matches[2].groups, <String?>['c', '3', 'x']);
    expect(result.matches[2].named, <String, String?>{'k': 'c'});
    expect(result.truncated, isFalse);
  });

  test('offset results: zero-length, astral and no-match runs', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    final RegexOk empty = await run(session, 'z', 'abc') as RegexOk;
    expect(empty.matches, isEmpty);
    final RegexOk zero = await run(session, r'\b', 'ab cd') as RegexOk;
    expect(zero.matches.map((RegexMatchInfo m) => m.start), <int>[0, 2, 3, 5]);
    expect(zero.matches.first.text, '');
    expect(zero.matches.first.groups, isEmpty);
    final RegexOk astral = await run(session, '.', 'a😀') as RegexOk;
    expect(astral.matches.map((RegexMatchInfo m) => m.text), <String>[
      'a',
      '😀',
    ]);
    expect(astral.matches.last.end, 3);
  });

  test('offset results honour the match cap', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    final RegexOk result =
        await run(session, '.', 'a' * (RegexTester.maxMatches + 5)) as RegexOk;
    expect(result.matches, hasLength(RegexTester.maxMatches));
    expect(result.truncated, isTrue);
    expect(result.matches.last.start, RegexTester.maxMatches - 1);
  });

  test(
    'RegexTester.runAsync selects the Web Worker (dart2js and wasm)',
    () async {
      final RegexResult result = await RegexTester.runAsync(
        pattern: r'(\d)',
        input: 'a1',
      );
      expect((result as RegexOk).matches.single.groups, <String?>['1']);
    },
  );
}
