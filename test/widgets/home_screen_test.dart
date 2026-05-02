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
