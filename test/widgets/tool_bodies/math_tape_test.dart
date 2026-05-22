import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/math_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> evaluate(WidgetTester tester, String expr) async {
    await tester.enterText(find.byType(EditableText).last, expr);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Math tape — hidden at phone width (mobile parity)', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const MathBody(), 340);

    await evaluate(tester, '2+3');
    await evaluate(tester, '4*5');

    // The Tape section header only renders in the wide canvas layout.
    expect(find.text('TAPE'), findsNothing);
  });

  testWidgets('Math tape — visible at wide width listing past evaluations', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const MathBody(), 640);

    await evaluate(tester, '2+3');
    await evaluate(tester, '4*5');

    expect(find.text('TAPE'), findsOneWidget);
    // The earlier evaluation (no longer in the input field) shows on the tape.
    expect(find.text('2+3'), findsOneWidget);
    // The latest expression appears both in the input field and on the tape.
    expect(find.text('4*5'), findsWidgets);
    // 20 appears both as the live result and on the tape.
    expect(find.text('20'), findsWidgets);
  });
}
