import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/tool_body_scaffold.dart';

void main() {
  group('isWhitespaceOnly', () {
    test('matches trim().isEmpty for every BMP code unit', () {
      for (int unit = 0; unit <= 0xFFFF; unit++) {
        final String s = String.fromCharCode(unit);
        expect(
          isWhitespaceOnly(s),
          s.trim().isEmpty,
          reason: 'U+${unit.toRadixString(16).padLeft(4, '0')}',
        );
      }
    });

    test('matches trim().isEmpty on mixed strings', () {
      for (final String s in <String>[
        '',
        ' ',
        ' \t\n\r\u000b\u000c',
        '  　﻿',
        '  a  ',
        '\n\n.',
        'x',
        ' ​ ',
      ]) {
        expect(isWhitespaceOnly(s), s.trim().isEmpty, reason: '"$s"');
      }
    });
  });
}
