import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/number_base_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

Finder _outputCell(String value) =>
    find.descendant(of: find.byType(MqMonoCell), matching: find.text(value));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Number Base — bit grid hidden at phone width (mobile parity)', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const NumberBaseBody(), 340);
    await enter(tester, '5');

    // The base conversions still render, but the bit-grid section header does
    // not — the body is identical to today below the canvas threshold.
    expect(_outputCell('5'), findsOneWidget);
    expect(find.text('BITS'), findsNothing);
  });

  testWidgets('Number Base — bit grid visible + interactive at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const NumberBaseBody(), 640);
    await enter(tester, '5'); // 0b0101

    expect(find.text('BITS'), findsOneWidget);
    // 5 = 0101 → bit 0 set, bit 1 clear, bit 2 set, bit 3 clear. The cell wraps
    // its bit/index text in semantics, so match the label as a substring.
    expect(find.bySemanticsLabel(RegExp('Bit 0 set')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Bit 1 clear')), findsOneWidget);

    // Toggling bit 1 turns 5 → 7.
    await tester.tap(find.bySemanticsLabel(RegExp('Bit 1 clear')));
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('7'), findsOneWidget);
    expect(_outputCell('0b111'), findsOneWidget);
  });
}
