import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<Finder> findHero(WidgetTester tester) async {
    final Finder input = find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField &&
          w.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
    );
    expect(input, findsOneWidget, reason: 'Hero composer must be on home');
    return input;
  }

  ToolGridCard cardFor(WidgetTester tester, String utilityId) {
    return tester
        .widgetList<ToolGridCard>(find.byType(ToolGridCard))
        .firstWhere((ToolGridCard c) => c.descriptor.id == utilityId);
  }

  testWidgets('renders all 9 catalog tools as grid cards', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Iterable<ToolGridCard> cards = tester.widgetList<ToolGridCard>(
      find.byType(ToolGridCard),
    );
    expect(cards.length, UtilityCatalog.all.length);
    expect(
      cards.map((ToolGridCard c) => c.descriptor.id).toSet(),
      UtilityCatalog.all.map((UtilityDescriptor u) => u.id).toSet(),
    );
  });

  testWidgets('idle hero shows paste + scan icons, no Clear button', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Paste'), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel('Scan QR'), findsAtLeastNWidgets(1));
    // The MqButton variant exposes its label as text; absent in idle.
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('hero content reveals Paste/Clear button row', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = await findHero(tester);
    await tester.enterText(hero, '#ff5733');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
  });

  testWidgets('typing JSON marks JSON card as matched', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = await findHero(tester);
    await tester.enterText(hero, '{"hello":"world"}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(cardFor(tester, 'json').matched, isTrue);
    expect(cardFor(tester, 'timestamp').matched, isFalse);
  });

  testWidgets('multi-format input matches multiple cards', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = await findHero(tester);
    await tester.enterText(hero, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(cardFor(tester, 'timestamp').matched, isTrue);
    expect(cardFor(tester, 'number_base').matched, isTrue);
  });

  testWidgets('clearing hero drops match highlights', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = await findHero(tester);
    await tester.enterText(hero, '#ff5733');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(cardFor(tester, 'color').matched, isTrue);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(cardFor(tester, 'color').matched, isFalse);
  });

  testWidgets('tap on a tool card pushes ToolDetailRoute seeded with hero', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = await findHero(tester);
    await tester.enterText(hero, '{"hello":"world"}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) => w is ToolGridCard && w.descriptor.id == 'json',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ToolDetailRoute), findsOneWidget);
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'json');
    expect(route.seed, '{"hello":"world"}');
  });

  testWidgets('grid sorts matched first, then recents, then remainder', (
    WidgetTester tester,
  ) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(utilityId: 'base64', ts: now),
        historyEntry(utilityId: 'json', ts: now - 1000),
      ]),
    });

    await pumpHomeWithLoadedHistory(tester);

    final Finder hero = find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField &&
          w.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
    );
    // Color match (hero is a hex) → Color card jumps to first.
    await tester.enterText(hero, '#abcdef');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    final List<String> ids = tester
        .widgetList<ToolGridCard>(find.byType(ToolGridCard))
        .map((ToolGridCard c) => c.descriptor.id)
        .toList();
    final int colorIdx = ids.indexOf('color');
    final int base64Idx = ids.indexOf('base64');
    final int jsonIdx = ids.indexOf('json');
    final int cronIdx = ids.indexOf('cron');
    expect(colorIdx, 0, reason: 'matched goes first');
    expect(base64Idx < cronIdx, isTrue, reason: 'recent above remainder');
    expect(jsonIdx < cronIdx, isTrue, reason: 'recent above remainder');
  });
}
