import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/utf8_length.dart';

void main() {
  const List<String> samples = <String>[
    '',
    'ascii only',
    'é',
    'ßü€',
    '中文字符',
    '😀',
    'a😀b👩‍💻c',
    '\u007f\u0080߿ࠀ￿',
    '\ud800',
    '\udc00',
    'x\ud800y',
    '\udc00\ud800',
    '\ud83d',
    '\ud83d😀',
  ];

  test('matches utf8.encode on ASCII, BMP, astral and lone surrogates', () {
    for (final String sample in samples) {
      expect(utf8Length(sample), utf8.encode(sample).length, reason: sample);
    }
  });

  test('matches utf8.encode on random code units', () {
    final Random random = Random(7);
    const List<int> pool = <int>[
      0x41,
      0x7f,
      0x80,
      0xe9,
      0x7ff,
      0x800,
      0x4e2d,
      0xd800,
      0xd83d,
      0xdbff,
      0xdc00,
      0xde00,
      0xdfff,
      0xe000,
      0xfffd,
      0xffff,
    ];
    for (int round = 0; round < 2000; round++) {
      final String value = String.fromCharCodes(<int>[
        for (int i = 0; i < random.nextInt(12); i++)
          pool[random.nextInt(pool.length)],
      ]);
      final int expected = utf8.encode(value).length;
      expect(utf8Length(value), expected, reason: value.codeUnits.toString());
      for (final int limit in <int>[0, 1, expected - 1, expected, 40]) {
        expect(
          utf8LengthExceeds(value, limit),
          expected > limit,
          reason: '${value.codeUnits} vs $limit',
        );
      }
    }
  });

  test('exceeds fast paths agree with the exact count', () {
    expect(utf8LengthExceeds('abc', 2), isTrue);
    expect(utf8LengthExceeds('中中', 6), isFalse);
    expect(utf8LengthExceeds('中中', 5), isTrue);
    expect(utf8LengthExceeds('😀', 3), isTrue);
    expect(utf8LengthExceeds('😀', 4), isFalse);
  });
}
