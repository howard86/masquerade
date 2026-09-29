import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/encoding_parser.dart';

/// Everything the Home/footer UI reads from a match, flattened for equality.
List<Object?> _describe(List<DetectionMatch<Object?>> matches) => <Object?>[
  for (final DetectionMatch<Object?> m in matches)
    <Object?>[
      m.artifact.kind,
      m.primaryToolId,
      m.confidence,
      m.reason,
      m.artifact.rawValue,
      m.artifact.provenance,
      m.artifact.sensitivity,
      (m.compatibleToolIds.toList()..sort()).join(','),
      m.artifact.parserResult.runtimeType,
      if (m.artifact.parserResult case final EncodingResult r) r.result,
      if (m.artifact.parserResult case final List<Object?> l) l.join('\n'),
    ],
];

String _lines(int bytes, String Function(int i) line) {
  final StringBuffer b = StringBuffer();
  for (int i = 0; b.length < bytes; i++) {
    b.writeln(line(i));
  }
  return b.toString().trimRight();
}

final List<String> _corpus = <String>[
  // Short scalars.
  '', ' ', '42', '1', '-7', '+12', '1700000000', '-1700000000',
  '1700000000000', '17000000000000000000000', '0x1F', '0b1010', '0o17',
  'deadbeef', 'ff', '1010', '0.25', '25bps', '25 bps', '12%', '1e5',
  'now', 'Today', 'last week', 'NEXT   month', 'yesterday!',
  '2026-01-01', '2026-01-01T10:00:00Z', '2026-01-01 10:00:00.123+02:00',
  '2026-01-01t10:00:00z', '+002026-01-01', '2026-13-45',
  // Cron (syntax, macros, natural language, near misses).
  '0 0 * * *', '*/5 * * * *', '0 9 * * 1-5', '0,15,30,45 * * * *',
  '@daily', '@weekly', '@bogus', '0 0 * * * *', '0 0 L * *', '0 0 ? * *',
  'every monday at 9am', 'at 14:30 on weekdays', 'every 15 minutes',
  'hourly', 'every weekday', 'monday, wednesday and friday',
  'every monday, tuesday, wednesday, thursday, friday, saturday, sunday',
  'every 5 minutes at 9am', 'at 9', 'every wednesdayy',
  // Identifiers / encodings / hashes.
  'helloWorld', 'hello_world', 'hello-world', 'HelloWorld', 'List',
  'aGVsbG8gd29ybGQ=', 'aGVsbG8gd29ybGQ', 'SGVsbG8=', 'AAAA', 'AA==',
  '5d41402abc4b2a76b9719d911017c592',
  'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d',
  '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
  '550e8400-e29b-41d4-a716-446655440000', '01ARZ3NDEKTSV4RRFFQ69G5FAV',
  'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.c2lnbmF0dXJl',
  // Network / URL / color.
  '192.168.0.1', '10.0.0.0/8', '::1', '2001:db8::/32', '999.1.1.1',
  'a=1&b=2', 'https://x.test/path?q=1&r=%20', 'hello%20world', '?a=b',
  '#ff0000', '#abc', 'rgb(255, 0, 0)', 'hsl(184, 100%, 38%)', 'red',
  // Math.
  '1+2', '2 * (3 + 4)', 'sqrt(16)', 'sin(pi/2)', 'pi', 'e', 'ans + 1',
  '10 % 3', '2^10', '1 2', '3x', '(1+2', 'max(1, 2, 3)', '1+2\n+3',
  'SIN(1)', 'foo(1)', '1+2=3', '0.5%',
  // Bytes / lists.
  '72 101 108 108 111', '[72, 101, 108]', '[1,2,300]', '0x48 0x69',
  '1, 2, 3', '[', '- one\n- two\n- three', '1. first\n2. second',
  '* a\n* b\nplain', 'one\ntwo\nthree',
  // Structured.
  '{"a":1}', '[1,2,3]', '{"a":1,}', '{"a":', '[section]\nkey = "v"',
  'key = "value"\nother = 2', 'name: demo\nitems:\n  - a\n  - b', '---\na: 1',
  'A=1\nB=2', 'export TOKEN=abc\nexport HOST=x', 'Host: x\nAccept: y',
  'id,name\n1,a\n2,b', 'a\tb\n1\t2\n3\t4', 'INFO,1\nWARN,2',
  // Markdown.
  '# Title\n\nSome **bold** and `code`.',
  '## A\n- item\n- item\n\n[link](https://x.test)',
  '| a | b |\n| --- | --- |\n| 1 | 2 |', '> quote\n> more\n\n---',
  '```\ncode\n```\ntext',
  // PEM.
  '-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----',
];

List<String> _synthetic() {
  final List<String> out = <String>[
    _lines(
      20000,
      (int i) =>
          '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}T10:00:00Z '
          'INFO worker[$i] id=$i status=200',
    ),
    const JsonEncoder.withIndent('  ').convert(<Object?>[
      for (int i = 0; i < 300; i++)
        <String, Object?>{'id': i, 'name': 'item-$i'},
    ]),
    'id,name,qty\n${_lines(20000, (int i) => '$i,item$i,${i % 50}')}',
    base64Encode(utf8.encode('printable payload ' * 1000)),
    _lines(20000, (int i) => '- item $i'),
    _lines(20000, (int i) => 'plain prose line number $i without markers'),
    '${'1+' * 3000}1',
    List<String>.filled(3000, '7').join(' '),
    'every monday${', tuesday' * 400}',
    '${List<String>.filled(200, '0').join(',')} 0 * * *',
    '2026-01-01T10:00:00.${'1' * 5000}Z',
    '1' * 5000,
    'f' * 5000,
    'now\n' * 3,
  ];
  for (final String name in <String>['x509_leaf.pem', 'x509_root.pem']) {
    final File file = File('test/fixtures/$name');
    if (file.existsSync()) out.add(file.readAsStringSync());
  }
  return out;
}

void main() {
  group('detectArtifacts fast paths', () {
    final List<String> inputs = <String>[
      for (final String s in <String>[..._corpus, ..._synthetic()]) ...<String>[
        s,
        '  $s\n',
        s.toUpperCase(),
      ],
    ];

    test('match the uncached, unfiltered oracle for every input', () {
      for (final String input in inputs) {
        for (final ArtifactProvenance provenance in <ArtifactProvenance>[
          ArtifactProvenance.typed,
          ArtifactProvenance.generated,
        ]) {
          expect(
            _describe(
              UtilityCatalog.detectArtifacts(input, provenance: provenance),
            ),
            _describe(
              UtilityCatalog.debugDetectArtifactsUncached(
                input,
                provenance: provenance,
              ),
            ),
            reason:
                'input: ${input.length > 80 ? input.substring(0, 80) : input}',
          );
        }
      }
    });

    test('each descriptor detector agrees with the oracle outside a sweep', () {
      for (final String input in inputs.take(60)) {
        final List<DetectionMatch<Object?>> direct = <DetectionMatch<Object?>>[
          for (final UtilityDescriptor tool in UtilityCatalog.all)
            ...?tool.detectArtifact?.call(input, ArtifactProvenance.typed),
        ];
        final Set<String> ids = direct
            .map((DetectionMatch<Object?> m) => m.primaryToolId)
            .toSet();
        final Set<String> oracle = UtilityCatalog.debugDetectArtifactsUncached(
          input,
        ).map((DetectionMatch<Object?> m) => m.primaryToolId).toSet();
        expect(ids, oracle, reason: input);
      }
    });

    test('byId / byIdOrNull resolve every catalog entry', () {
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        expect(UtilityCatalog.byId(tool.id), same(tool));
        expect(UtilityCatalog.byIdOrNull(tool.id), same(tool));
      }
      expect(UtilityCatalog.byIdOrNull('nope'), isNull);
      expect(() => UtilityCatalog.byId('nope'), throwsStateError);
    });
  });
}
