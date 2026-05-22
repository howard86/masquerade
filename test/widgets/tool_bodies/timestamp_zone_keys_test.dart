import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/timestamp_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets(
    'Timestamp — zone toggle + quick keys hidden at phone width (parity)',
    (WidgetTester tester) async {
      await pumpBodyAtWidth(tester, const TimestampBody(), 340);
      await enter(tester, '0');

      // Mobile parity: no UTC/Local toggle, no Now / Start-of-day keys; both
      // UTC and Local rows still render exactly as before.
      expect(find.text('Now'), findsNothing);
      expect(find.text('Start of day'), findsNothing);
      expect(find.text('UTC'), findsOneWidget); // the mono cell label only
      expect(find.text('Local'), findsOneWidget);
    },
  );

  testWidgets('Timestamp — zone toggle + quick keys visible at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const TimestampBody(), 640);
    await enter(tester, '0'); // 1970-01-01T00:00:00Z

    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Start of day'), findsOneWidget);

    // Default zone is UTC: the UTC date row shows, the Local row is collapsed.
    expect(find.text('1970-01-01 00:00:00'), findsOneWidget);

    // "Now" sets the input to a current epoch in seconds, parsed as a recent
    // instant — the unix-epoch (0) row is gone afterwards.
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('1970-01-01 00:00:00'), findsNothing);
  });
}
