import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/utility_catalog.dart';

void main() {
  List<String> ids(String input) => UtilityCatalog.detectAll(
    input,
  ).map((UtilityDescriptor u) => u.id).toList();

  group('UtilityCatalog.detectAll', () {
    test('empty / whitespace returns no candidates', () {
      expect(ids(''), isEmpty);
      expect(ids('   '), isEmpty);
      expect(ids('\n\t'), isEmpty);
    });

    test('JSON object only suggests JSON', () {
      expect(ids('{"a":1}'), <String>['json']);
    });

    test('JSON array of small ints co-fires JSON + Bytes', () {
      // Bracketed integer list parses as JSON and as a byte array.
      expect(ids('[1, 2, 3]'), <String>['json', 'bytes']);
    });

    test('space-separated bytes only suggests Bytes', () {
      expect(ids('72 101 108 108 111'), <String>['bytes']);
    });

    test('bracketed byte list co-fires JSON + Bytes', () {
      expect(ids('[72, 101, 108, 108, 111]'), <String>['json', 'bytes']);
    });

    test('single integer does not suggest Bytes', () {
      // Single tokens stay with Number Base / Timestamp.
      expect(ids('72'), isNot(contains('bytes')));
    });

    test('out-of-range list does not suggest Bytes', () {
      expect(ids('256 1 2'), isNot(contains('bytes')));
    });

    test('hex color with # only suggests Color', () {
      expect(ids('#ff5733'), <String>['color']);
    });

    test('bare hex string suggests Number Base + Color, not Base64', () {
      // ff5733 is valid as hex digits → number base, also a 6-char hex color.
      // Base64 detection rejects pure-hex strings without padding.
      expect(ids('ff5733'), <String>['number_base', 'color']);
    });

    test('unix seconds suggests Timestamp + Number Base, not bps', () {
      // 1700000000 has length 10, not divisible by 4, so isBase64 rejects.
      // bps detector requires explicit suffix or abs ≤ 1, so it stays quiet.
      expect(ids('1700000000'), <String>['number_base', 'timestamp']);
    });

    test('unix milliseconds suggests Timestamp + Number Base', () {
      expect(ids('1700000000000'), <String>['number_base', 'timestamp']);
    });

    test('ISO 8601 only suggests Timestamp', () {
      expect(ids('2023-11-14T22:13:20Z'), <String>['timestamp']);
    });

    test('Base64 with padding only suggests Base64', () {
      // SGVsbG8= decodes to "Hello" — printable bytes pass the gate.
      expect(ids('SGVsbG8='), <String>['base64']);
    });

    test('explicit bps suffix only suggests bps', () {
      expect(ids('25 bps'), <String>['bps']);
    });

    test('percent suffix only suggests bps', () {
      expect(ids('0.25%'), <String>['bps']);
    });

    test('small decimal without suffix only suggests bps', () {
      expect(ids('0.05'), <String>['bps']);
    });

    test('rgb() function only suggests Color', () {
      expect(ids('rgb(255, 0, 0)'), <String>['color']);
    });

    test('hsl() function only suggests Color', () {
      expect(ids('hsl(184, 100%, 38%)'), <String>['color']);
    });

    test('0x prefix only suggests Number Base', () {
      expect(ids('0xFF'), <String>['number_base']);
    });

    test('binary prefix only suggests Number Base', () {
      expect(ids('0b1010'), <String>['number_base']);
    });

    test('garbage input returns no candidates', () {
      expect(ids('!@#\$%^&*()'), isEmpty);
      expect(ids('not a real input ~~~'), isEmpty);
    });
  });
}
