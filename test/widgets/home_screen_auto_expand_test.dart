import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<Finder> heroInput(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    return find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField &&
          w.placeholder == 'Timestamp, JSON, hex, base64, color…',
    );
  }

  /// The expanded `InlineToolCard` header carries a unique `chevron_left`
  /// icon that no collapsed chip uses; tapping it (any tap inside the
  /// header bubbles to the outer `_toggle` GestureDetector) collapses the
  /// active card.
  final Finder expandedHeaderHit = find.byIcon(MqIcons.chevL);

  testWidgets('single-match input auto-expands without chip tap', (
    WidgetTester tester,
  ) async {
    final Finder hero = await heroInput(tester);
    await tester.enterText(hero, '{"a":1}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    // 'Pretty' is body-only — its presence proves the body mounted.
    expect(find.text('Pretty'), findsOneWidget);
  });

  testWidgets('two-match input does not auto-expand', (
    WidgetTester tester,
  ) async {
    final Finder hero = await heroInput(tester);
    // 1700000000 fires Timestamp + Number Base.
    await tester.enterText(hero, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    // Suggestion row visible, but no body unfurled.
    expect(find.text('Open in'), findsOneWidget);
    // Number Base body's 'Detected base' header is body-only.
    expect(find.text('DETECTED BASE'), findsNothing);
    expect(find.text('Pretty'), findsNothing);
  });

  testWidgets('manual override sticks across re-seed', (
    WidgetTester tester,
  ) async {
    final Finder hero = await heroInput(tester);

    // Auto-expand JSON via a single-match seed.
    await tester.enterText(hero, '{"a":1}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Pretty'), findsOneWidget);

    // Manual collapse via the expanded header's chevron-left icon.
    await tester.tap(expandedHeaderHit);
    await tester.pumpAndSettle();
    expect(find.text('Pretty'), findsNothing);

    // Edit hero — the same single-match input must NOT re-trigger auto-expand
    // because the user override is still set.
    await tester.enterText(hero, '{"b":2}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Pretty'), findsNothing);
  });

  testWidgets('clearing the hero re-arms auto-expand', (
    WidgetTester tester,
  ) async {
    final Finder hero = await heroInput(tester);

    await tester.enterText(hero, '{"a":1}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Pretty'), findsOneWidget);

    // Manual collapse via the chevron — sets the override flag.
    await tester.tap(expandedHeaderHit);
    await tester.pumpAndSettle();
    expect(find.text('Pretty'), findsNothing);

    // Tap the Clear button — clears hero AND resets the override.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // A fresh single-match seed now auto-expands again.
    await tester.enterText(hero, '{"c":3}');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('Pretty'), findsOneWidget);
  });
}
