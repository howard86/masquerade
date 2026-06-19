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

    await tester.enterText(find.byType(EditableText).last, '255');
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

    await tester.enterText(find.byType(EditableText).last, '0xFF');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 16'), findsOneWidget);
    expect(_outputCell('255'), findsOneWidget);
  });

  testWidgets('Number Base — 0b-prefixed binary detects base 2', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '0b1010');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 2'), findsOneWidget);
    expect(_outputCell('10'), findsOneWidget);
  });

  testWidgets('Number Base — invalid hex digit surfaces a precise reason', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '0xG1');
    await tester.pumpAndSettle(kDebouncePump);

    // The precise reason names the offending digit and its base, surfaced
    // inline via MqInput.error instead of a generic "invalid" state.
    expect(find.text('"g" is not a valid hexadecimal digit.'), findsOneWidget);
  });
}
