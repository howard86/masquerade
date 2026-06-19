import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/number_base_parser.dart';

/// Unwraps a successful parse, failing the test with the carried error when the
/// result is a [NumberBaseError].
NumberBaseResult _ok(String input) {
  final NumberBaseParseResult r = NumberBaseParser.parse(input);
  expect(r, isA<NumberBaseOk>(), reason: 'expected $input to parse');
  return (r as NumberBaseOk).result;
}

String _err(String input) {
  final NumberBaseParseResult r = NumberBaseParser.parse(input);
  expect(r, isA<NumberBaseError>(), reason: 'expected $input to fail');
  return (r as NumberBaseError).message;
}

void main() {
  group('NumberBaseParser', () {
    test('parses 0xFF as base 16 → 255', () {
      final NumberBaseResult r = _ok('0xFF');
      expect(r.detectedBase, 16);
      expect(r.decimal, '255');
      expect(r.hex, '0xFF');
      expect(r.binary, '0b11111111');
      expect(r.octal, '0o377');
    });

    test('parses 0b1010 as base 2 → 10', () {
      final NumberBaseResult r = _ok('0b1010');
      expect(r.detectedBase, 2);
      expect(r.decimal, '10');
    });

    test('parses 0o777 as base 8 → 511', () {
      final NumberBaseResult r = _ok('0o777');
      expect(r.detectedBase, 8);
      expect(r.decimal, '511');
    });

    test('parses 0o377 as base 8 → 255', () {
      final NumberBaseResult r = _ok('0o377');
      expect(r.detectedBase, 8);
      expect(r.decimal, '255');
    });

    test('parses plain decimal', () {
      final NumberBaseResult r = _ok('255');
      expect(r.detectedBase, 10);
      expect(r.hex, '0xFF');
    });

    test('detects hex without prefix when contains a-f', () {
      final NumberBaseResult r = _ok('deadbeef');
      expect(r.detectedBase, 16);
    });

    test('handles negative numbers', () {
      final NumberBaseResult r = _ok('-42');
      expect(r.decimal, '-42');
    });

    test('handles big integers beyond 64-bit', () {
      final NumberBaseResult r = _ok('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');
      expect(
        r.value,
        BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', radix: 16),
      );
    });

    group('precise errors', () {
      test('invalid hex digit names the offending char', () {
        final String message = _err('0xG1');
        expect(message, contains('g'));
        expect(message, contains('hexadecimal'));
      });

      test('binary digit out of 0/1 names the offending char', () {
        final String message = _err('0b012');
        expect(message, contains('2'));
        expect(message, contains('binary'));
      });

      test('octal digit out of range names the offending char', () {
        final String message = _err('0o8');
        expect(message, contains('8'));
        expect(message, contains('octal'));
      });

      test('prefix with no digits asks for digits', () {
        final String message = _err('0x');
        expect(message.toLowerCase(), contains('hexadecimal'));
      });

      test('empty input returns an actionable reason, not null', () {
        expect(_err(''), isNotEmpty);
        expect(_err('   '), isNotEmpty);
      });

      test('pure garbage names the bad character', () {
        final String message = _err('not a number');
        expect(message, isNotEmpty);
      });
    });
  });
}
