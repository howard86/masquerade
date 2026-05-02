import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/utils/bps_parser.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('bps — explicit "bps" suffix detects BPS form', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText), '100bps');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.bps.name.toUpperCase()), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('1.0000%'), findsOneWidget);
    expect(find.text('0.010000'), findsOneWidget);
  });

  testWidgets('bps — "%" suffix detects PERCENT form and back-computes bps', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText), '0.5%');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.percent.name.toUpperCase()), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('0.5000%'), findsOneWidget);
    expect(find.text('0.005000'), findsOneWidget);
  });

  testWidgets('bps — bare small decimal detects DECIMAL form', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText), '0.025');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.decimal.name.toUpperCase()), findsOneWidget);
    expect(find.text('250.00'), findsOneWidget);
    expect(find.text('2.5000%'), findsOneWidget);
    expect(find.text('0.025000'), findsOneWidget);
  });

  testWidgets('bps — non-numeric input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText), 'not a rate');
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.textContaining('Could not parse as bps, % or decimal'),
      findsOneWidget,
    );
  });
}
