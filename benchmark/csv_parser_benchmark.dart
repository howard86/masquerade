import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:masquerade/utils/csv_parser.dart';

void main(List<String> args) {
  final String fixture = args.firstOrNull ?? 'comma';
  if (fixture == 'correctness') {
    stdout.writeln(
      jsonEncode(<String, Object>{'digest': _correctnessDigest()}),
    );
    return;
  }
  final bool transform = args.elementAtOrNull(1) == 'transform';
  final String input = _fixture(fixture);
  const int warmups = 10;
  const int samples = 30;
  var checksum = 0;

  Object run() {
    final CsvParseResult result = CsvParser.parse(input);
    if (transform && result is CsvOk) return CsvParser.toJson(result);
    return result;
  }

  for (var i = 0; i < warmups; i++) {
    checksum ^= run().hashCode;
  }
  final List<int> times = <int>[];
  for (var i = 0; i < samples; i++) {
    final Stopwatch watch = Stopwatch()..start();
    final Object result = run();
    watch.stop();
    checksum ^= result.hashCode;
    times.add(watch.elapsedMicroseconds);
  }
  final CsvParseResult result = CsvParser.parse(input);
  stdout.writeln(
    jsonEncode(<String, Object>{
      'fixture': fixture,
      'mode': transform ? 'transform' : 'parse',
      'inputBytes': utf8.encode(input).length,
      'warmups': warmups,
      'samplesUs': times,
      'digest': _digest(_canonical(result)),
      'checksum': checksum,
    }),
  );
}

String _fixture(String fixture) => switch (fixture) {
  'comma' => _table(','),
  'tab' => _table('\t'),
  'semicolon' => _table(';'),
  'quoted' => _table(',', rows: 5000, quoted: true),
  'ambiguous' => <String>[
    'a,b;c',
    for (var row = 0; row < 9999; row++) '$row,x$row;y$row',
  ].join('\n'),
  _ => throw ArgumentError.value(fixture, 'fixture'),
};

String _table(String delimiter, {int rows = 10000, bool quoted = false}) =>
    <String>[
      <String>[
        for (var column = 0; column < 10; column++) 'c$column',
      ].join(delimiter),
      for (var row = 1; row < rows; row++)
        <String>[
          for (var column = 0; column < 10; column++)
            quoted
                ? _quote('v${row % 100},;\t"$column')
                : '${(row + column) % 1000}',
        ].join(delimiter),
    ].join('\n');

String _correctnessDigest() {
  final List<Object?> results = <Object?>[];
  var state = 0x5eed1234;
  for (var index = 0; index < 10000; index++) {
    state = (1664525 * state + 1013904223) & 0xffffffff;
    final String delimiter = CsvParser.delimiters[index % 3];
    final String lineBreak = index.isEven ? '\n' : '\r\n';
    final String prefix = index % 5 == 0 ? '\ufeff' : '';
    final List<String> cells = <String>[
      'v${state % 97}',
      switch (index % 6) {
        0 => 'comma,value',
        1 => 'tab\tvalue',
        2 => 'semi;value',
        3 => 'quote"value',
        4 => 'line\nvalue',
        _ => '',
      },
      '😀${state % 11}',
    ];
    String input =
        '$prefix${<String>['a', 'b', 'c'].join(delimiter)}'
        '$lineBreak${cells.map(_quote).join(delimiter)}';
    if (index % 7 == 0) input += lineBreak;
    input = switch (index % 17) {
      0 => '$input"',
      1 => '$input${delimiter}extra',
      2 => '$input${lineBreak}ragged',
      _ => input,
    };
    final bool? hasHeader = switch (index % 4) {
      0 => null,
      1 => true,
      2 => false,
      _ => null,
    };
    results.add(_canonical(CsvParser.parse(input, hasHeader: hasHeader)));
  }
  return _digest(results);
}

Object _canonical(CsvParseResult result) => switch (result) {
  CsvErr(:final message) => <Object?>['error', message],
  CsvOk(:final delimiter, :final hasHeader, :final header, :final rows) =>
    <Object?>['ok', delimiter, hasHeader, header, rows],
};

String _quote(String value) => '"${value.replaceAll('"', '""')}"';

String _digest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
