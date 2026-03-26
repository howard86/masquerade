import 'package:flutter_test/flutter_test.dart';
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
}
