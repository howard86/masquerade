import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/log_stack_inspector.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

void main() {
  test('strips ANSI, normalizes time, detects levels, and groups stacks', () {
    final LogInspection result = LogStackInspector.parse(
      '\u001b[31m2026-07-18T09:10:11+08:00 ERROR failed\u001b[0m\n'
      'java.lang.IllegalStateException: nope\n'
      '  at app.Main.run(Main.java:1)\n'
      '{"timestamp":1721264400000,"level":"info","message":"ok"}',
    );

    expect(result.events, hasLength(2));
    expect(result.events.first.level, LogLevel.error);
    expect(result.events.first.startLine, 1);
    expect(result.events.first.endLine, 3);
    expect(result.events.first.text, contains('at app.Main.run'));
    expect(result.events.first.text, isNot(contains('\u001b')));
    expect(result.events.first.normalizedTimestamp, '2026-07-18T01:10:11.000Z');
    expect(result.events.last.level, LogLevel.info);
    expect(result.events.last.timestampUtc, isNotNull);
  });

  test('redacts every outward model surface before storage', () {
    const String jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature';
    final LogInspection result = LogStackInspector.parse(
      'Authorization: Bearer raw-bearer\n'
      'Cookie: sid=raw-cookie\n'
      'GET https://user:raw-pass@example.com?token=raw-query\n'
      'aws=AKIAABCDEFGHIJKLMNOP\n'
      '{"level":"ERROR","nested":{"password":"raw-json"},"jwt":"$jwt"}\n'
      '-----BEGIN PRIVATE KEY-----\nraw-private\n-----END PRIVATE KEY-----',
    );
    final String exported = result.export(result.events);

    expect(exported, contains(SensitiveDataPolicy.mask));
    for (final String secret in <String>[
      'raw-bearer',
      'raw-cookie',
      'raw-pass',
      'raw-query',
      'AKIAABCDEFGHIJKLMNOP',
      'raw-json',
      jwt,
      'raw-private',
    ]) {
      expect(exported, isNot(contains(secret)), reason: secret);
      expect(
        result.events.expand((LogEvent event) => event.artifacts).join(),
        isNot(contains(secret)),
      );
    }
    expect(exported, contains('[REDACTED PRIVATE KEY]'));
  });

  test('mixed JSONL and plain logs preserve source event order', () {
    final LogInspection result = LogStackInspector.parse(
      '{"message":"one","api_key":"hide"}\n'
      'plain two\n'
      '[2026-07-18 09:00:00] WARN three\n'
      '  continuation',
    );

    expect(result.events.map((LogEvent event) => event.startLine), <int>[
      1,
      2,
      3,
    ]);
    expect(result.events.last.endLine, 4);
    expect(result.events.last.level, LogLevel.warn);
    expect(result.events.first.text, contains('"api_key":"••••"'));
    expect(result.events[1].text, 'plain two');

    final LogInspection harmless = LogStackInspector.parse(
      '{ "message" : "safe" }',
    );
    expect(harmless.hadSensitiveInput, isFalse);
  });

  test('filters bounded safe text without changing order', () {
    final LogInspection result = LogStackInspector.parse(
      'INFO alpha\nERROR beta\nWARN alphabet',
    );
    expect(
      result
          .filter(
            levels: <LogLevel>{LogLevel.info, LogLevel.warn},
            query: 'alp',
          )
          .map((LogEvent event) => event.startLine),
      <int>[1, 3],
    );
    expect(
      () => result.filter(query: 'x' * 257),
      throwsA(isA<LogInspectorException>()),
    );
  });

  test('extracts four unique safe artifacts in appearance order', () {
    const String uuid = '550e8400-e29b-41d4-a716-446655440000';
    const String base64 = 'SGVsbG8gV29ybGQ=';
    const String hex =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const String percent = 'hello%20world';
    final LogEvent event = LogStackInspector.parse(
      'INFO id=$uuid blob=$base64 hash=$hex encoded=$percent https://fifth.example',
    ).events.single;

    expect(event.artifacts, <String>[uuid, base64, hex, percent]);
    expect(
      LogStackInspector.parse('INFO abc123def456g').events.single.artifacts,
      isEmpty,
    );
    expect(
      LogStackInspector.parse(
        'INFO AAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAA '
        'AAAAAAAAAAAAAAAA SGVsbG8gV29ybGQ=',
      ).events.single.artifacts,
      <String>['SGVsbG8gV29ybGQ='],
    );
  });

  test('masks protected reversible encodings before model construction', () {
    final String encoded = base64Encode(utf8.encode('password=raw-secret'));
    final LogInspection result = LogStackInspector.parse(
      'INFO $encoded password%3Draw-secret',
    );
    final LogEvent event = result.events.single;
    expect(event.text, contains(SensitiveDataPolicy.mask));
    expect(event.text, isNot(contains(encoded)));
    expect(event.text, isNot(contains('password%3Draw-secret')));
    expect(event.artifacts, isEmpty);
    expect(result.hadSensitiveInput, isTrue);
  });

  test('handles CSI and OSC terminators in linear scan', () {
    final LogInspection result = LogStackInspector.parse(
      '\u001b]0;secret title\u0007INFO bell\n'
      '\u001b]8;;https://example.com\u001b\\link\u001b]8;;\u001b\\',
    );
    expect(result.events.first.text, 'INFO bell');
    expect(result.events.last.text, 'link');
  });

  test('fails closed at every public bound without echoing source', () {
    expect(
      () => LogStackInspector.parse(
        'x' * (LogStackInspector.maxInputCharacters + 1),
      ),
      throwsA(
        isA<LogInspectorException>().having(
          (LogInspectorException error) => error.message,
          'safe message',
          isNot(contains('xxx')),
        ),
      ),
    );
    expect(
      () => LogStackInspector.parse(
        'x' * (LogStackInspector.maxLineCharacters + 1),
      ),
      throwsA(isA<LogInspectorException>()),
    );
    expect(
      () => LogStackInspector.parse('-----BEGIN PRIVATE KEY-----\nsecret'),
      throwsA(isA<LogInspectorException>()),
    );
  });

  test('large bounded fixture remains complete and ordered', () {
    final String input = List<String>.generate(
      4000,
      (int index) => '${1700000000 + index} INFO event-$index',
    ).join('\n');
    final Stopwatch watch = Stopwatch()..start();
    final LogInspection result = LogStackInspector.parse(input);
    watch.stop();

    expect(result.events, hasLength(4000));
    expect(result.events.first.text, contains('event-0'));
    expect(result.events.last.text, contains('event-3999'));
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('incomplete ANSI and DCS controls never swallow the next record', () {
    for (final String control in <String>[
      '\u001b[31',
      '\u001b]title',
      '\u001bPpayload',
      '\u009b31',
      '\u009dtitle',
      '\u0090payload',
      '\u001b',
    ]) {
      final LogInspection result = LogStackInspector.parse(
        '$control\n2026-07-18T00:00:00Z INFO next',
      );
      expect(result.events.last.text, contains('INFO next'), reason: control);
    }
    expect(
      LogStackInspector.parse(
        '\u001bPdrop\u001b\\INFO kept',
      ).events.single.text,
      'INFO kept',
    );
  });

  test('redacts standalone credentials, providers, and broad private keys', () {
    final LogInspection result = LogStackInspector.parse(
      'Bearer standalone-secret\n'
      'Basic c3VwZXItc2VjcmV0\n'
      'cookie=hidden-cookie\n'
      'ghp_abcdefghijklmnopqrstuvwxyz1234\n'
      'github_pat_abcdefghijklmnopqrstuvwxyz_1234\n'
      'xoxb-1234567890-secret\n'
      '-----BEGIN PGP PRIVATE KEY BLOCK-----\nprivate-body\n'
      '-----END PGP PRIVATE KEY BLOCK-----',
    );
    final String safe = result.export(result.events);
    for (final String secret in <String>[
      'standalone-secret',
      'c3VwZXItc2VjcmV0',
      'hidden-cookie',
      'ghp_',
      'github_pat_',
      'xoxb-',
      'private-body',
    ]) {
      expect(safe, isNot(contains(secret)));
    }
    expect(result.events.last.startLine, 7);
    expect(result.events.last.endLine, 9);
    expect(result.hadSensitiveInput, isTrue);

    final LogInspection json = LogStackInspector.parse(
      '[{"password":"array-secret"},{"Authorization: Bearer key-secret":"safe"}]',
    );
    expect(json.events.single.text, isNot(contains('array-secret')));
    expect(json.events.single.text, isNot(contains('key-secret')));
    expect(json.events.single.artifacts.single, isNot(contains('key-secret')));
    expect(
      LogStackInspector.parse('[REDACTED PRIVATE KEY]').events.single.artifacts,
      isEmpty,
    );
    expect(
      LogStackInspector.parse('[TRUNCATED JSON]').events.single.artifacts,
      isEmpty,
    );
    expect(
      LogStackInspector.parse(
        '{"password":"malformed-secret"',
      ).events.single.text,
      isNot(contains('malformed-secret')),
    );
  });

  test('timestamp normalization is strict and machine-independent', () {
    final LogInspection result = LogStackInspector.parse(
      '[2026-07-18 09:00:00] INFO utc\n'
      '2026-02-31T01:02:03Z INFO invalid\n'
      'request 1700000000 INFO id\n'
      '1700000000 INFO epoch',
    );
    expect(result.events[0].normalizedTimestamp, '2026-07-18T09:00:00.000Z');
    expect(result.events[1].timestampUtc, isNull);
    expect(result.events[2].timestampUtc, isNull);
    expect(result.events[3].normalizedTimestamp, '2023-11-14T22:13:20.000Z');
  });

  test('plain levels are prefix-only and stack markers win', () {
    final LogInspection result = LogStackInspector.parse(
      'request info only\n'
      'at com.Info.run(Main.java:1)\n'
      'INFO healthy\n'
      'Traceback (most recent call last):\n'
      '  File "app.py", line 1\n'
      'ValueError: bad\n'
      '2026-07-18T00:00:00Z INFO after',
    );
    expect(result.events.first.level, LogLevel.unknown);
    expect(result.events.first.text, contains('com.Info'));
    final LogEvent traceback = result.events.firstWhere(
      (LogEvent event) => event.text.startsWith('Traceback'),
    );
    expect(traceback.text, contains('ValueError'));
    expect(traceback.text, isNot(contains('INFO healthy')));
    expect(result.events.last.text, endsWith('INFO after'));
  });

  test('groups representative stacks without swallowing adjacent events', () {
    for (final String stack in <String>[
      'ERROR java\njava.lang.Error: bad\nSuppressed: x\n  at Main.run',
      'Error: js\n    at run (app.js:1)',
      'Traceback (most recent call last):\n  File "a.py", line 1\nValueError: bad',
      'Unhandled exception:\nException: dart\n#0 main',
      "thread 'main' panicked at bad\nnote: run with backtrace\nstack backtrace:\n0: main",
      'System.Exception: outer\n ---> System.Exception: inner\n--- End of inner exception stack trace ---\n   at App.Run()',
    ]) {
      final LogInspection result = LogStackInspector.parse(
        '$stack\n2026-07-18T00:00:00Z INFO next',
      );
      expect(
        result.events.first.endLine,
        stack.split('\n').length,
        reason: stack,
      );
      expect(result.events.last.text, endsWith('INFO next'), reason: stack);
    }
  });

  test('preflights deep JSON and reports event truncation exactly', () {
    final String deep = '${'[' * 14}"api_key":"secret"${']' * 14}';
    final LogInspection json = LogStackInspector.parse(deep);
    expect(json.events.single.text, '[TRUNCATED JSON]');
    expect(json.hadSensitiveInput, isTrue);

    final String exact = List<String>.filled(
      LogStackInspector.maxEvents,
      'plain',
    ).join('\n');
    expect(LogStackInspector.parse(exact).truncated, isFalse);
    expect(LogStackInspector.parse('$exact\nextra').truncated, isTrue);
  });

  test('large single stack remains linear', () {
    final String input = <String>[
      'ERROR failed',
      ...List<String>.generate(9000, (int i) => '  at frame$i'),
    ].join('\n');
    final Stopwatch watch = Stopwatch()..start();
    final LogInspection result = LogStackInspector.parse(input);
    watch.stop();
    expect(result.events, hasLength(1));
    expect(result.events.single.endLine, 9001);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('dense candidate fixture stays bounded', () {
    final String input = List<String>.filled(800, 'SGVsbG8gV29ybGQ=').join(' ');
    final Stopwatch watch = Stopwatch()..start();
    final LogEvent event = LogStackInspector.parse(input).events.single;
    watch.stop();
    expect(event.artifacts, <String>['SGVsbG8gV29ybGQ=']);
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('exports 5000 owned events linearly in source order', () {
    final LogInspection result = LogStackInspector.parse(
      List<String>.generate(
        5000,
        (int index) => 'INFO event-$index',
      ).join('\n'),
    );
    final Stopwatch watch = Stopwatch()..start();
    final String exported = result.export(result.events);
    watch.stop();
    expect(exported, startsWith('INFO event-0\n'));
    expect(exported, endsWith('INFO event-4999'));
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));

    final LogEvent foreign = LogStackInspector.parse(
      'INFO foreign',
    ).events.single;
    expect(
      result.export(<LogEvent>[result.events[2], foreign, result.events[0]]),
      'INFO event-0\nINFO event-2',
    );
  });
}
