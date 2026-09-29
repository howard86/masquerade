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
}
