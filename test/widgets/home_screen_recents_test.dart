import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/widgets/mq/mq_recents_row.dart';

import '_helpers.dart';

void main() {
  testWidgets('empty history → no Recents row', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpHomeWithLoadedHistory(tester);

    expect(find.byType(MqRecentsRow), findsNothing);
    expect(find.text('RECENTS'), findsNothing);
  });

  testWidgets('history with 2 distinct tools → 2 chips newest-first', (
    WidgetTester tester,
  ) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        // Newest entry first (HistoryController stores newest at index 0).
        historyEntry(utilityId: 'base64', ts: now),
        historyEntry(utilityId: 'json', ts: now - 1000),
        historyEntry(utilityId: 'json', ts: now - 2000),
      ]),
    });

    await pumpHomeWithLoadedHistory(tester);

    expect(find.byType(MqRecentsRow), findsOneWidget);
    expect(find.text('RECENTS'), findsOneWidget);

    final MqRecentsRow row = tester.widget<MqRecentsRow>(
      find.byType(MqRecentsRow),
    );
    expect(row.recents.map((u) => u.id).toList(), <String>['base64', 'json']);
  });

  testWidgets('retention Off → no Recents row even with entries', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.retention.days': 0,
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(utilityId: 'base64'),
      ]),
    });

    await pumpHomeWithLoadedHistory(tester);

    expect(find.byType(MqRecentsRow), findsNothing);
  });

  testWidgets('tapping a recents chip opens that tool inline', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(utilityId: 'base64'),
      ]),
    });

    await pumpHomeWithLoadedHistory(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(MqRecentsRow),
        matching: find.text('Base64'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encode'), findsOneWidget);
    expect(find.text('Decode'), findsOneWidget);
  });
}
