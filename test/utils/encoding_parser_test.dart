import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/encoding_parser.dart';

void main() {
  group('EncodingParser.isBase64', () {
    test('accepts a valid 4-char block', () {
      expect(EncodingParser.isBase64('AAAA'), isTrue);
    });

    test('accepts a padded block', () {
      expect(EncodingParser.isBase64('AAA='), isTrue);
    });

    test('rejects length not a multiple of 4', () {
      expect(EncodingParser.isBase64('AAA'), isFalse);
    });

    test('rejects 5-char input even with padding', () {
      expect(EncodingParser.isBase64('AAAA='), isFalse);
    });

    test('rejects characters outside the base64 alphabet', () {
      expect(EncodingParser.isBase64('@@@@'), isFalse);
    });

    test('treats empty string as valid (trims to len 0, decodes to empty)', () {
      // Documents actual behavior: '' matches the regex, len % 4 == 0, and
      // base64Decode('') succeeds, so isBase64('') is true.
      expect(EncodingParser.isBase64(''), isTrue);
    });

    test('trims surrounding whitespace before validating', () {
      expect(EncodingParser.isBase64('  AAAA  '), isTrue);
    });
  });

  group('EncodingParser.isHex', () {
    test('accepts 0x-prefixed hex', () {
      expect(EncodingParser.isHex('0xDeadBeef'), isTrue);
    });

    test('accepts #-prefixed hex', () {
      expect(EncodingParser.isHex('#FF00FF'), isTrue);
    });

    test('accepts bare even-length hex', () {
      expect(EncodingParser.isHex('FF'), isTrue);
    });

    test('rejects odd-length hex', () {
      expect(EncodingParser.isHex('0xFFF'), isFalse);
    });

    test('rejects non-hex characters', () {
      expect(EncodingParser.isHex('xyz'), isFalse);
    });

    test('accepts mixed lower/upper case', () {
      expect(EncodingParser.isHex('aB'), isTrue);
      expect(EncodingParser.isHex('deadBEEF'), isTrue);
    });
  });

  group('EncodingParser.parseHexToBase10', () {
    test('decodes 0x-prefixed hex to text', () {
      expect(EncodingParser.parseHexToBase10('0x4869'), 'Hi');
    });

    test('decodes #-prefixed hex to text', () {
      expect(EncodingParser.parseHexToBase10('#4869'), 'Hi');
    });

    test('returns null on invalid hex', () {
      expect(EncodingParser.parseHexToBase10('xyz'), isNull);
      expect(EncodingParser.parseHexToBase10('0xFFF'), isNull);
    });
  });

  group('EncodingParser.parseBase64ToBase10', () {
    test('decodes a padded base64 string to text', () {
      expect(EncodingParser.parseBase64ToBase10('SGk='), 'Hi');
    });

    test('returns null on invalid base64', () {
      expect(EncodingParser.parseBase64ToBase10('@@@@'), isNull);
      expect(EncodingParser.parseBase64ToBase10('AAA'), isNull);
    });
  });

  group('EncodingParser.detectAndConvert', () {
    test('returns unknown for empty input', () {
      final EncodingResult r = EncodingParser.detectAndConvert('');
      expect(r.type, EncodingType.unknown);
      expect(r.isUnknown, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.isEmpty, isTrue);
      expect(r.original, '');
    });

    test('returns unknown for whitespace-only input', () {
      // Whitespace trims to empty, so it takes the empty/unknown branch.
      final EncodingResult r = EncodingParser.detectAndConvert('   ');
      expect(r.type, EncodingType.unknown);
      expect(r.original, '');
    });

    test('detects even-length all-hex as hex (hex is tried first)', () {
      final EncodingResult r = EncodingParser.detectAndConvert('deadbeef');
      expect(r.type, EncodingType.hex);
      expect(r.isSuccess, isTrue);
      expect(r.original, 'deadbeef');
    });

    test('detects base64-only (non-hex) input as base64', () {
      // 'SGk=' fails isHex (contains S/G/k and '=') but is valid base64.
      final EncodingResult r = EncodingParser.detectAndConvert('SGk=');
      expect(r.type, EncodingType.base64);
      expect(r.result, 'Hi');
      expect(r.isSuccess, isTrue);
      expect(r.original, 'SGk=');
    });

    test('returns unknown for garbage', () {
      final EncodingResult r = EncodingParser.detectAndConvert('@@@@!');
      expect(r.type, EncodingType.unknown);
      expect(r.isUnknown, isTrue);
      expect(r.isEmpty, isTrue);
    });
  });

  group('EncodingParser.isValidEncodedFormat', () {
    test('true for valid base64', () {
      expect(EncodingParser.isValidEncodedFormat('SGk='), isTrue);
    });

    test('true for valid hex', () {
      expect(EncodingParser.isValidEncodedFormat('FF'), isTrue);
    });

    test('false for garbage', () {
      expect(EncodingParser.isValidEncodedFormat('@@@@!'), isFalse);
    });
  });
}
