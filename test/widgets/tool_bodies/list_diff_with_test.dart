import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/tool_bodies/list_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Phase 7 unlock: at canvas-wide width the List body surfaces an inline
/// count readout and a "Diff with…" action; below 460 neither shows
/// (mobile parity — the count still lives on the output cell hint).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  UtilityDescriptor? routed;
  String? routedInput;

  Widget body() => ListToolBody(
    onSwitchTool: (UtilityDescriptor u, String input) {
      routed = u;
      routedInput = input;
    },
  );

  Future<void> enter(WidgetTester tester) async {
    await tester.enterText(find.byType(EditableText).last, 'BTC\nETH\nBTC');
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('List — Diff with… hidden + count only on cell at phone width', (
    WidgetTester tester,
  ) async {
    routed = null;
    await pumpBodyAtWidth(tester, body(), 340);
    await enter(tester);

    expect(find.text('Diff with…'), findsNothing);
    // The count lives only on the output cell hint — no standalone readout.
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('List — Diff with… + standalone count readout at wide width', (
    WidgetTester tester,
  ) async {
    routed = null;
    await pumpBodyAtWidth(tester, body(), 640);
    await enter(tester);

    expect(find.text('Diff with…'), findsOneWidget);
    // Now the count shows twice: the cell hint plus the inline readout.
    expect(find.text('3 items'), findsNWidgets(2));

    await tester.tap(find.text('Diff with…'));
    await tester.pumpAndSettle();

    expect(routed?.id, 'diff');
    expect(routedInput, 'BTC\nETH\nBTC');
  });
}
