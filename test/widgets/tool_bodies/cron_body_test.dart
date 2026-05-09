import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('cron — 5-field expression renders canonical and description', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Cron');

    await tester.enterText(find.byType(EditableText).last, '0 9 * * 1-5');
    await tester.pumpAndSettle(kDebouncePump);

    // Input field echoes the typed text plus the canonical row renders it.
    expect(find.text('0 9 * * 1-5'), findsNWidgets(2));
    expect(find.text('At 09:00 on weekdays.'), findsOneWidget);
  });

  testWidgets('cron — @daily surfaces macro row', (WidgetTester tester) async {
    await pumpHomeAndOpen(tester, 'Cron');

    await tester.enterText(find.byType(EditableText).last, '@daily');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('0 0 * * *'), findsOneWidget);
    // Input echoes '@daily' + macro row renders '@daily'.
    expect(find.text('@daily'), findsNWidgets(2));
  });

  testWidgets('cron — natural language round-trips to canonical', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Cron');

    await tester.enterText(
      find.byType(EditableText).last,
      'every monday at 9am',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('0 9 * * 1'), findsOneWidget);
    // MqStatus uppercases the label.
    expect(find.text('NATURAL LANGUAGE'), findsOneWidget);
  });

  testWidgets('cron — invalid input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Cron');

    await tester.enterText(
      find.byType(EditableText).last,
      'penguins ride bicycles',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Unsupported'), findsOneWidget);
  });

  testWidgets('cron — impossible schedule shows "no upcoming runs"', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Cron');

    // Feb 30 — never fires.
    await tester.enterText(find.byType(EditableText).last, '0 0 30 2 *');
    await tester.pumpAndSettle(kDebouncePump);

    // Input field + canonical row both render '0 0 30 2 *'.
    expect(find.text('0 0 30 2 *'), findsNWidgets(2));
    expect(find.textContaining('No upcoming runs'), findsOneWidget);
  });

  testWidgets('cron — Quartz extension rejected with named error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Cron');

    await tester.enterText(find.byType(EditableText).last, '0 0 ? * MON');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Quartz'), findsOneWidget);
  });
}
