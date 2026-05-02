import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

import '_helpers.dart';

Finder _outputCell(String value) =>
    find.descendant(of: find.byType(MqMonoCell), matching: find.text(value));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Number Base — decimal input emits all four representations', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText), '255');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 10'), findsOneWidget);
    expect(_outputCell('255'), findsOneWidget);
    expect(_outputCell('0xFF'), findsOneWidget);
    expect(_outputCell('0o377'), findsOneWidget);
    expect(_outputCell('0b11111111'), findsOneWidget);
  });

  testWidgets('Number Base — 0x-prefixed hex detects base 16', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText), '0xFF');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 16'), findsOneWidget);
    expect(_outputCell('255'), findsOneWidget);
  });

  testWidgets('Number Base — 0b-prefixed binary detects base 2', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText), '0b1010');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 2'), findsOneWidget);
    expect(_outputCell('10'), findsOneWidget);
  });

  testWidgets('Number Base — non-numeric input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText), 'xyz!');
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.textContaining('Could not parse as a number in any base'),
      findsOneWidget,
    );
  });
}
