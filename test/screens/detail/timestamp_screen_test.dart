import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openTimestamp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final Finder timestampTile = find.text('Timestamp');
    expect(timestampTile, findsWidgets);
    await tester.tap(timestampTile.last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Timestamp ambiguity badge shows for values in seconds/ms overlap range',
    (WidgetTester tester) async {
      await openTimestamp(tester);

      final Finder input = find.byType(EditableText);
      await tester.enterText(input, '1700000000');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('AMBIGUOUS'), findsOneWidget);
    },
  );

  testWidgets('Timestamp ambiguity badge hidden for unambiguous ms value', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '1700000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('AMBIGUOUS'), findsNothing);
  });

  testWidgets('16-digit input renders Unix µs label', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '1700000000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 'µ' (U+00B5) uppercases to Greek capital Mu (U+039C) in Dart's default
    // locale, so the rendered badge text contains 'ΜS' not 'µS'.
    expect(find.text('UNIX ΜS'), findsOneWidget);
  });

  testWidgets('19-digit input renders Unix ns label', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '1700000000000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('UNIX NS'), findsOneWidget);
  });

  testWidgets('naïve ISO renders local-TZ-assumed badge', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '2023-11-14T22:13:20');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('LOCAL TZ ASSUMED'), findsOneWidget);
  });

  testWidgets('ISO with Z does not show local-TZ-assumed badge', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '2023-11-14T22:13:20Z');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('LOCAL TZ ASSUMED'), findsNothing);
  });

  testWidgets('picking today from anchor sheet resolves as Keyword', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    // Tap the trailing clock icon → opens the keyword picker modal.
    await tester.tap(find.bySemanticsLabel('Insert keyword'));
    await tester.pumpAndSettle();

    // Tap the Anchor select row inside the modal.
    await tester.tap(find.text('now / today / yesterday / tomorrow'));
    await tester.pumpAndSettle();

    // Pick `today` from the nested action sheet.
    await tester.tap(find.text('today'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Dismiss the modal.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('KEYWORD'), findsOneWidget);
  });

  testWidgets('picking last + hour from pair row resolves composite Keyword', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    await tester.tap(find.bySemanticsLabel('Insert keyword'));
    await tester.pumpAndSettle();

    // Tap the Relative compact row — its visible value is the default 'this'.
    await tester.tap(find.text('this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('last'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Modal refresh: 'this' gone, 'last' visible in the row.
    expect(find.text('this'), findsNothing);
    expect(find.text('last'), findsOneWidget);

    // Input auto-updates immediately (before Done).
    EditableText liveInput = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(liveInput.controller.text, 'last hour');

    // Tap the Unit compact row — its visible value is the default 'hour'.
    // Two 'hour' texts now exist: the row value and the action sheet item.
    // The first one is the row; tap it to open the picker.
    await tester.tap(find.text('hour').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('day').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Input updates again after second pick.
    liveInput = tester.widget<EditableText>(find.byType(EditableText));
    expect(liveInput.controller.text, 'last day');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('KEYWORD'), findsOneWidget);
  });

  testWidgets('typing now resolves as Keyword', (WidgetTester tester) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText);
    await tester.enterText(input, 'now');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('KEYWORD'), findsOneWidget);
  });
}
