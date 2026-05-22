import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/cron_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Phase 7 unlock: at canvas-wide width the Cron body renders a 7-day fire
/// strip (the upcoming fires within the next week); below 460 it is absent
/// (mobile parity — the Next 5 cell already covers upcoming runs).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester) async {
    // Hourly — guarantees several fires inside the next 7 days.
    await tester.enterText(find.byType(EditableText).last, '0 * * * *');
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('cron — 7-day fire strip hidden at phone width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const CronBody(), 340);
    await enter(tester);

    expect(find.text('NEXT 7 DAYS'), findsNothing);
  });

  testWidgets('cron — 7-day fire strip visible at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const CronBody(), 640);
    await enter(tester);

    // MqSectionHeader uppercases its label.
    expect(find.text('NEXT 7 DAYS'), findsOneWidget);
  });
}
