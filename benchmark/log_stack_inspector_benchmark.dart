import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:masquerade/utils/log_stack_inspector.dart';

void main(List<String> args) {
  final String fixture = args.singleOrNull ?? 'plain';
  final String input = _fixture(fixture);
  const int warmups = 10;
  const int samples = 30;
  var checksum = 0;

  for (var i = 0; i < warmups; i++) {
    checksum ^= LogStackInspector.parse(input).events.length;
  }

  final times = <int>[];
  for (var i = 0; i < samples; i++) {
    final watch = Stopwatch()..start();
    final result = LogStackInspector.parse(input);
    watch.stop();
    checksum ^= result.events.length + result.events.last.endLine;
    times.add(watch.elapsedMicroseconds);
  }

  final result = LogStackInspector.parse(input);
  final canonical = jsonEncode(<Object?>[
    result.truncated,
    result.hadSensitiveInput,
    for (final event in result.events)
      <Object?>[
        event.startLine,
        event.endLine,
        event.level.name,
        event.normalizedTimestamp,
        event.text,
        event.artifacts,
      ],
  ]);
  stdout.writeln(
    jsonEncode(<String, Object>{
      'fixture': fixture,
      'inputBytes': utf8.encode(input).length,
      'warmups': warmups,
      'samplesUs': times,
      'digest': sha256.convert(utf8.encode(canonical)).toString(),
      'checksum': checksum,
    }),
  );
}

String _fixture(String fixture) => switch (fixture) {
  'plain' => List<String>.generate(
    5000,
    (i) =>
        '2026-08-12T10:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}Z INFO request-$i completed code=200',
  ).join('\n'),
  'jsonl' => List<String>.generate(
    5000,
    (i) => jsonEncode(<String, Object>{
      'timestamp': '2026-08-12T10:00:00Z',
      'level': i.isEven ? 'info' : 'warn',
      'message': 'request-$i completed',
      'code': 200,
    }),
  ).join('\n'),
  'mixed' => List<String>.generate(
    5000,
    (i) => i % 10 == 0
        ? jsonEncode(<String, Object>{
            'timestamp': '2026-08-12T10:00:00Z',
            'level': 'error',
            'message': 'request-$i failed',
            'token': 'secret-$i',
          })
        : '2026-08-12T10:00:00Z INFO request-$i completed code=200',
  ).join('\n'),
  _ => throw ArgumentError.value(fixture, 'fixture'),
};
