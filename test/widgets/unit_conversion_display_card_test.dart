import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/unit_parser.dart';
import 'package:masquerade/widgets/unit_conversion_display_card.dart';

void main() {
  group('UnitConversionDisplayCard', () {
    testWidgets('renders category label', (tester) async {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.length,
        fromValue: 1.0,
        fromUnit: 'm',
        conversions: {
          'mm': 1000.0,
          'cm': 100.0,
          'm': 1.0,
          'km': 0.001,
          'in': 39.3701,
          'ft': 3.28084,
          'yd': 1.09361,
          'mi': 0.000621371,
        },
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: UnitConversionDisplayCard(result: result),
            ),
          ),
        ),
      );

      expect(find.text('Length'), findsOneWidget);
    });

    testWidgets('renders a row for each unit', (tester) async {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.weight,
        fromValue: 1.0,
        fromUnit: 'kg',
        conversions: {
          'mg': 1000000.0,
          'g': 1000.0,
          'kg': 1.0,
          'lb': 2.20462,
          'oz': 35.274,
        },
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: UnitConversionDisplayCard(result: result),
            ),
          ),
        ),
      );

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
      expect(find.text('lb'), findsOneWidget);
    });
  });
}
