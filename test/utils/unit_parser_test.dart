import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/encoding_parser.dart';
import 'package:masquerade/utils/unit_parser.dart';

void main() {
  group('UnitParseResult', () {
    test('empty result has isSuccess false and unknown category', () {
      const result = UnitParseResult.empty;
      expect(result.isSuccess, isFalse);
      expect(result.category, UnitCategory.unknown);
      expect(result.errorMessage, isNull);
      expect(result.conversions, isEmpty);
    });

    test('successful result carries conversions', () {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.length,
        fromValue: 1.0,
        fromUnit: 'm',
        conversions: {'km': 0.001, 'mm': 1000.0},
      );
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.length);
      expect(result.fromValue, 1.0);
      expect(result.fromUnit, 'm');
      expect(result.conversions['km'], 0.001);
      expect(result.conversions['mm'], 1000.0);
    });

    test('error result carries errorMessage', () {
      const result = UnitParseResult(
        isSuccess: false,
        category: UnitCategory.unknown,
        errorMessage: 'Unknown unit',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Unknown unit');
    });
  });

  group('UnitParser._parseUnitConversion (via parse)', () {
    group('length', () {
      test('converts 1 m to all length units', () {
        final result = UnitParser.parse('1m');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.length);
        expect(result.fromUnit, 'm');
        expect(result.conversions['mm'], closeTo(1000.0, 0.001));
        expect(result.conversions['cm'], closeTo(100.0, 0.001));
        expect(result.conversions['km'], closeTo(0.001, 0.000001));
        expect(result.conversions['ft'], closeTo(3.28084, 0.0001));
        expect(result.conversions['mi'], closeTo(0.000621371, 0.0000001));
      });

      test('converts 1 km to meters', () {
        final result = UnitParser.parse('1km');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['m'], closeTo(1000.0, 0.001));
      });

      test('is case-insensitive for unit', () {
        final result = UnitParser.parse('1KM');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.length);
      });

      test('handles space between value and unit', () {
        final result = UnitParser.parse('100 km');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['m'], closeTo(100000.0, 0.001));
      });
    });

    group('weight', () {
      test('converts 1 kg to all weight units', () {
        final result = UnitParser.parse('1kg');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.weight);
        expect(result.conversions['g'], closeTo(1000.0, 0.001));
        expect(result.conversions['lb'], closeTo(2.20462, 0.0001));
        expect(result.conversions['oz'], closeTo(35.274, 0.001));
      });
    });

    group('temperature', () {
      test('converts 0 C to F and K', () {
        final result = UnitParser.parse('0C');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.temperature);
        expect(result.conversions['F'], closeTo(32.0, 0.001));
        expect(result.conversions['K'], closeTo(273.15, 0.001));
      });

      test('converts 100 C to F', () {
        final result = UnitParser.parse('100C');
        expect(result.conversions['F'], closeTo(212.0, 0.001));
      });

      test('converts -40 F to C (crossover point)', () {
        final result = UnitParser.parse('-40F');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['C'], closeTo(-40.0, 0.001));
      });

      test('converts 300 K to C', () {
        final result = UnitParser.parse('300K');
        expect(result.conversions['C'], closeTo(26.85, 0.01));
      });
    });

    group('volume', () {
      test('converts 1 l to ml', () {
        final result = UnitParser.parse('1l');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.volume);
        expect(result.conversions['ml'], closeTo(1000.0, 0.001));
      });

      test('converts 1 cup to ml', () {
        final result = UnitParser.parse('1cup');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['ml'], closeTo(236.588, 0.001));
      });
    });

    group('data size', () {
      test('converts 1 GB to MB and KB', () {
        final result = UnitParser.parse('1GB');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.dataSize);
        expect(result.conversions['MB'], closeTo(1024.0, 0.001));
        expect(result.conversions['KB'], closeTo(1048576.0, 0.001));
      });

      test('converts 1 TB to GB', () {
        final result = UnitParser.parse('1TB');
        expect(result.conversions['GB'], closeTo(1024.0, 0.001));
      });
    });

    group('time duration', () {
      test('converts 1 hr to minutes and seconds', () {
        final result = UnitParser.parse('1hr');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.timeDuration);
        expect(result.conversions['min'], closeTo(60.0, 0.001));
        expect(result.conversions['s'], closeTo(3600.0, 0.001));
        expect(result.conversions['ms'], closeTo(3600000.0, 0.001));
      });

      test('converts 1 week to days', () {
        final result = UnitParser.parse('1week');
        expect(result.conversions['day'], closeTo(7.0, 0.001));
      });
    });

    group('error cases', () {
      test('returns failure for empty input', () {
        final result = UnitParser.parse('');
        expect(result.isSuccess, isFalse);
        expect(result.category, UnitCategory.unknown);
      });

      test('returns failure for unknown unit', () {
        final result = UnitParser.parse('100xyz');
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('returns failure for bare number with no unit', () {
        // A float with no unit should fail unit conversion
        final result = UnitParser.parse('3.14');
        expect(result.isSuccess, isFalse);
      });
    });
  });

  group('UnitParser.parse — encoding delegation', () {
    test('detects base64 and sets encoding category', () {
      // "aGVsbG8=" is base64 for "hello"
      final result = UnitParser.parse('aGVsbG8=');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.encoding);
      expect(result.encodingResult, isNotNull);
      expect(result.encodingResult!.type, EncodingType.base64);
    });

    test('detects hex string and sets encoding category', () {
      // "68656c6c6f" is hex for "hello"
      final result = UnitParser.parse('68656c6c6f');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.encoding);
      expect(result.encodingResult!.type, EncodingType.hex);
    });
  });

  group('UnitParser.parse — timestamp delegation', () {
    test('detects Unix timestamp (pure integer)', () {
      final result = UnitParser.parse('1672531200');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.timestamp);
      expect(result.timestamp, isNotNull);
      expect(result.timestamp!.year, 2023);
    });

    test('detects ISO 8601 date string', () {
      final result = UnitParser.parse('2023-11-14T22:13:20Z');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.timestamp);
      expect(result.timestamp!.year, 2023);
    });

    test('pure integer is not treated as hex', () {
      // "1714000000" contains only 0-9 chars (valid hex chars)
      // but should be treated as a timestamp, not encoding
      final result = UnitParser.parse('1714000000');
      expect(result.category, UnitCategory.timestamp);
    });
  });
}
