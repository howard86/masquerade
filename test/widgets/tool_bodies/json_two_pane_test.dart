import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/json_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Phase 7 unlock: at canvas-wide width the Input and rendered Output sit
/// side-by-side; below 460 they stay stacked (mobile parity).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester) async {
    await tester.enterText(find.byType(EditableText).last, '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('JSON — Input over Output (stacked) at phone width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const JSONBody(), 340);
    await enter(tester);

    final Offset input = tester.getTopLeft(find.byType(EditableText).last);
    final Offset output = tester.getTopLeft(find.byType(MqMonoCell).first);

    // Stacked: the output cell sits below the input field.
    expect(output.dy, greaterThan(input.dy));
    expect((output.dx - input.dx).abs(), lessThan(8));
  });

  testWidgets('JSON — Input ‖ Output (side-by-side) at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const JSONBody(), 640);
    await enter(tester);

    final Offset input = tester.getTopLeft(find.byType(EditableText).last);
    final Offset output = tester.getTopLeft(find.byType(MqMonoCell).first);

    // Side-by-side: the output column starts to the right of the input column
    // and shares the same top band.
    expect(output.dx, greaterThan(input.dx + 100));
    expect((output.dy - input.dy).abs(), lessThan(8));
  });
}
