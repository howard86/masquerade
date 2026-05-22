import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/diff_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Phase 7 unlock: at canvas-wide width inputs A and B sit side-by-side;
/// below 460 they stay stacked (mobile parity).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Diff — A over B (stacked) at phone width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const DiffBody(), 340);

    final Offset a = tester.getTopLeft(find.byType(EditableText).first);
    final Offset b = tester.getTopLeft(find.byType(EditableText).last);

    expect(b.dy, greaterThan(a.dy));
    expect((b.dx - a.dx).abs(), lessThan(8));
  });

  testWidgets('Diff — A ‖ B (side-by-side) at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const DiffBody(), 640);

    final Offset a = tester.getTopLeft(find.byType(EditableText).first);
    final Offset b = tester.getTopLeft(find.byType(EditableText).last);

    expect(b.dx, greaterThan(a.dx + 100));
    expect((b.dy - a.dy).abs(), lessThan(8));
  });
}
