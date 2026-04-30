import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/number_base_parser.dart';

void main() {
  group('NumberBaseParser', () {
    test('parses 0xFF as base 16 → 255', () {
      final NumberBaseResult? r = NumberBaseParser.parse('0xFF');
      expect(r, isNotNull);
      expect(r!.detectedBase, 16);
      expect(r.decimal, '255');
      expect(r.hex, '0xFF');
      expect(r.binary, '0b11111111');
      expect(r.octal, '0o377');
    });

    test('parses 0b1010 as base 2 → 10', () {
      final NumberBaseResult? r = NumberBaseParser.parse('0b1010');
      expect(r, isNotNull);
      expect(r!.detectedBase, 2);
      expect(r.decimal, '10');
    });

    test('parses 0o377 as base 8 → 255', () {
      final NumberBaseResult? r = NumberBaseParser.parse('0o377');
      expect(r, isNotNull);
      expect(r!.detectedBase, 8);
      expect(r.decimal, '255');
    });

    test('parses plain decimal', () {
      final NumberBaseResult? r = NumberBaseParser.parse('42');
      expect(r, isNotNull);
      expect(r!.detectedBase, 10);
      expect(r.hex, '0x2A');
    });

    test('detects hex without prefix when contains a-f', () {
      final NumberBaseResult? r = NumberBaseParser.parse('deadbeef');
      expect(r, isNotNull);
      expect(r!.detectedBase, 16);
    });

    test('returns null on garbage', () {
      expect(NumberBaseParser.parse('not a number'), isNull);
      expect(NumberBaseParser.parse(''), isNull);
      expect(NumberBaseParser.parse('   '), isNull);
    });

    test('handles negative numbers', () {
      final NumberBaseResult? r = NumberBaseParser.parse('-42');
      expect(r, isNotNull);
      expect(r!.decimal, '-42');
    });

    test('handles big integers beyond 64-bit', () {
      final NumberBaseResult? r = NumberBaseParser.parse(
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
      );
      expect(r, isNotNull);
      expect(
        r!.value,
        BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', radix: 16),
      );
    });
  });
}
