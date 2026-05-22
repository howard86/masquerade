import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/bps_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

Finder _cell(String value) =>
    find.descendant(of: find.byType(MqMonoCell), matching: find.text(value));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('bps — pin-baseline affordance hidden at phone width (parity)', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const BpsBody(), 340);
    await enter(tester, '25 bps');

    expect(_cell('25.00'), findsOneWidget); // base output unchanged
    expect(find.text('Pin baseline'), findsNothing);
  });

  testWidgets('bps — pinning a baseline shows the delta at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const BpsBody(), 640);
    await enter(tester, '25 bps');

    expect(find.text('Pin baseline'), findsOneWidget);
    await tester.tap(find.text('Pin baseline'));
    await tester.pumpAndSettle();

    // Now enter a higher value; Δ = 40 - 25 = +15 bps.
    await enter(tester, '40 bps');
    expect(find.text('Δ vs baseline'.toUpperCase()), findsOneWidget);
    expect(_cell('+15.00'), findsOneWidget);
  });
}
