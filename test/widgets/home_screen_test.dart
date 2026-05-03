import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<Finder> findHeroInput(WidgetTester tester) async {
    final Finder input = find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField &&
          w.placeholder == 'Timestamp, JSON, hex, base64, color…',
    );
    expect(input, findsOneWidget, reason: 'Hero paste input must be on home');
    return input;
  }

  testWidgets('Home renders all 6 tool tiles by default', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Each tool name is shown on its tile (flat grid, no categories).
    expect(find.text('Timestamp'), findsWidgets);
    expect(find.text('Number Base'), findsWidgets);
    expect(find.text('JSON'), findsWidgets);
    expect(find.text('Base64'), findsWidgets);
    expect(find.text('Color'), findsWidgets);
    expect(find.text('bps · % · decimal'), findsWidgets);

    // No chips when input empty.
    expect(find.text('Open in'), findsNothing);
  });

  testWidgets('Typing JSON in hero surfaces JSON chip and seeds detail', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final Finder hero = await findHeroInput(tester);
    await tester.enterText(hero, '{"hello":"world"}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(find.text('Open in'), findsOneWidget);
    // JSON chip — name "JSON" appears as both a chip and the grid tile.
    // Tap the chip (last instance is the tile, first should be chip).
    final Finder jsonText = find.text('JSON');
    expect(jsonText, findsAtLeastNWidgets(2));

    // Find chip via location — chip is above the tile, so first match works.
    await tester.tap(jsonText.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // JSON detail screen: input pre-filled, output rendered.
    final Finder jsonInput = find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField && w.placeholder == '{"hello": "world"}',
    );
    expect(jsonInput, findsOneWidget);
    expect(
      (tester.widget(jsonInput) as CupertinoTextField).controller!.text,
      '{"hello":"world"}',
    );
  });

  testWidgets(
    'Tapping a collapsed card expands it inline; tapping another collapses the first',
    (WidgetTester tester) async {
      // Match `kDetailSurfaceSize` (480x1050) used by detail-screen tests so
      // ResponsiveLayout skips the iPhone-frame wrap (which would constrain
      // content width to 393 and overflow the inline card's 3-button bar).
      await tester.binding.setSurfaceSize(const Size(480, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Base64 card collapsed → no Encode/Decode segmented control yet.
      expect(find.text('Encode'), findsNothing);

      // Tap the Base64 card header.
      await tester.tap(find.text('Base64'));
      await tester.pumpAndSettle();

      // Body widgets visible inline (segmented control + Paste/Swap/Clear bar).
      expect(find.text('Encode'), findsOneWidget);
      expect(find.text('Decode'), findsOneWidget);
      // No CupertinoNavigationBar pushed — inline expansion, not navigation.
      expect(find.byType(CupertinoNavigationBar), findsNothing);

      // Tap the JSON card header — Base64 should collapse, JSON should expand.
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      expect(find.text('Encode'), findsNothing);
      expect(find.text('Pretty'), findsOneWidget);
    },
  );

  testWidgets('Multi-format hero input surfaces multiple chips', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final Finder hero = await findHeroInput(tester);
    // 1700000000 detects as both Timestamp (>=1e8) and Number Base (decimal).
    await tester.enterText(hero, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    // Both chips render under "Open in" label (tile copies of the names
    // also appear elsewhere — `findsAtLeastNWidgets(2)` covers chip + tile).
    expect(find.text('Open in'), findsOneWidget);
    expect(find.text('Timestamp'), findsAtLeastNWidgets(2));
    expect(find.text('Number Base'), findsAtLeastNWidgets(2));
  });

  testWidgets('Tapping the same chip twice toggles its card off', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final Finder hero = await findHeroInput(tester);
    await tester.enterText(hero, '{"a":1}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    // First tap on JSON chip expands JSON's body — the segmented control's
    // 'Pretty' label is body-only, not present in any tile/chip.
    await tester.tap(find.text('JSON').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Pretty'), findsOneWidget);

    // Second tap on the same chip collapses it.
    await tester.tap(find.text('JSON').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Pretty'), findsNothing);
  });

  testWidgets(
    'Expanded card and output rows persist across hero text changes',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final Finder hero = await findHeroInput(tester);
      await tester.enterText(hero, '{"a":1}');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      // Open the JSON card via its chip, seeding it with the hero text.
      await tester.tap(find.text('JSON').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Pretty'), findsOneWidget);

      // Clear the hero input. The chip row goes away …
      await tester.enterText(hero, '');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      expect(find.text('Open in'), findsNothing);

      // … but the JSON card body and the seeded controller's text remain.
      expect(find.text('Pretty'), findsOneWidget);
      final Finder jsonInput = find.byWidgetPredicate(
        (Widget w) =>
            w is CupertinoTextField && w.placeholder == '{"hello": "world"}',
      );
      expect(jsonInput, findsOneWidget);
      expect(
        (tester.widget(jsonInput) as CupertinoTextField).controller!.text,
        '{"a":1}',
      );
    },
  );

  testWidgets('Clearing hero input hides chips', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final Finder hero = await findHeroInput(tester);
    await tester.enterText(hero, '#ff5733');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Open in'), findsOneWidget);

    await tester.enterText(hero, '');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Open in'), findsNothing);
  });
}
