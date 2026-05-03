import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/bytes_parser.dart';

void main() {
  group('BytesParser.parse', () {
    test('parses plain space-separated integers', () {
      final BytesParseResult r = BytesParser.parse('72 101 108 108 111');
      expect(r, isA<BytesParseOk>());
      final BytesParseOk ok = r as BytesParseOk;
      expect(utf8.decode(ok.bytes), 'Hello');
    });

    test('parses bracketed comma list', () {
      final BytesParseResult r = BytesParser.parse('[72, 101, 108, 108, 111]');
      expect(r, isA<BytesParseOk>());
      expect(utf8.decode((r as BytesParseOk).bytes), 'Hello');
    });

    test('parses mixed whitespace and commas', () {
      final BytesParseResult r = BytesParser.parse('  72 ,101,  108 108 111  ');
      expect(r, isA<BytesParseOk>());
      expect(utf8.decode((r as BytesParseOk).bytes), 'Hello');
    });

    test('accepts tabs and newlines as separators', () {
      final BytesParseResult r = BytesParser.parse('72\t105\n33');
      expect(r, isA<BytesParseOk>());
      expect(utf8.decode((r as BytesParseOk).bytes), 'Hi!');
    });

    test('parses single byte', () {
      final BytesParseResult r = BytesParser.parse('65');
      expect(r, isA<BytesParseOk>());
      expect((r as BytesParseOk).bytes, <int>[65]);
    });

    test('rejects out-of-range integer', () {
      final BytesParseResult r = BytesParser.parse('256');
      expect(r, isA<BytesParseError>());
      expect((r as BytesParseError).message, contains('out of range'));
    });

    test('rejects negative integer', () {
      final BytesParseResult r = BytesParser.parse('-1');
      expect(r, isA<BytesParseError>());
      expect((r as BytesParseError).message, contains('out of range'));
    });

    test('rejects non-integer token', () {
      final BytesParseResult r = BytesParser.parse('72 abc 108');
      expect(r, isA<BytesParseError>());
      expect((r as BytesParseError).message, contains('Invalid integer'));
    });

    test('rejects empty input', () {
      expect(BytesParser.parse(''), isA<BytesParseError>());
      expect(BytesParser.parse('   '), isA<BytesParseError>());
    });

    test('rejects empty bracket pair', () {
      final BytesParseResult r = BytesParser.parse('[]');
      expect(r, isA<BytesParseError>());
      expect((r as BytesParseError).message, contains('No integers found'));
    });
  });

  group('BytesParser.format', () {
    test('space format', () {
      expect(
        BytesParser.format(BytesParser.encodeUtf8('Hi'), BytesFormat.space),
        '72 105',
      );
    });

    test('brackets format', () {
      expect(
        BytesParser.format(BytesParser.encodeUtf8('Hi'), BytesFormat.brackets),
        '[72, 105]',
      );
    });

    test('hex format pads to two digits', () {
      expect(
        BytesParser.format(BytesParser.encodeUtf8('Hi'), BytesFormat.hex),
        '48 69',
      );
    });

    test('handles full byte range in hex', () {
      final BytesParseResult r = BytesParser.parse('0 15 16 255');
      expect(r, isA<BytesParseOk>());
      expect(
        BytesParser.format((r as BytesParseOk).bytes, BytesFormat.hex),
        '00 0f 10 ff',
      );
    });
  });

  group('round-trip', () {
    test('encode then parse recovers bytes', () {
      const String text = 'Hello, world! 你好';
      final encoded = BytesParser.encodeUtf8(text);
      final formatted = BytesParser.format(encoded, BytesFormat.space);
      final BytesParseResult parsed = BytesParser.parse(formatted);
      expect(parsed, isA<BytesParseOk>());
      expect(utf8.decode((parsed as BytesParseOk).bytes), text);
    });
  });
}
