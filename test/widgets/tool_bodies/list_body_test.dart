import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('List — Join mode strips bullets and joins with comma', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'List');

    await tester.enterText(
      find.byType(EditableText).last,
      '- BTC\n- ETH\n- SOL',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BTC,ETH,SOL'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('List — Dedupe chip removes duplicate items', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'List');

    await tester.enterText(find.byType(EditableText).last, 'BTC, ETH, BTC');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('BTC,ETH,BTC'), findsOneWidget);

    await tester.tap(find.text('Dedupe'));
    await tester.pumpAndSettle();

    expect(find.text('BTC,ETH'), findsOneWidget);
    expect(find.text('3 items · 2 after dedupe'), findsOneWidget);
  });

  testWidgets('List — Quote chip wraps each item', (WidgetTester tester) async {
    await pumpHomeAndOpen(tester, 'List');

    await tester.enterText(find.byType(EditableText).last, 'BTC\nETH');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Quote'));
    await tester.pumpAndSettle();

    expect(find.text('"BTC","ETH"'), findsOneWidget);
  });

  testWidgets(
    'List — quote-style chip announces selected and flips on toggle',
    (WidgetTester tester) async {
      await pumpHomeAndOpen(tester, 'List');

      await tester.enterText(find.byType(EditableText).last, 'BTC\nETH');
      await tester.pumpAndSettle(kDebouncePump);

      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();

      // Default quote style is double-quote — the chip shows '"x"' and
      // announces itself as the active (selected) style.
      expect(
        tester.getSemantics(find.bySemanticsLabel('"x"')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(find.text('"BTC","ETH"'), findsOneWidget);

      await tester.tap(find.text('"x"'));
      await tester.pumpAndSettle();

      // Toggling to single-quote flips both the label and the selected flag.
      expect(
        tester.getSemantics(find.bySemanticsLabel("'x'")),
        isSemantics(isButton: true, isSelected: false),
      );
      expect(find.text("'BTC','ETH'"), findsOneWidget);
    },
  );

  testWidgets('List — separator field exposes an a11y button label', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'List');

    // Join mode (the default) shows the tappable separator picker; it must
    // announce itself as a button with its current value for screen readers.
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Separator: Comma',
      ),
      findsOneWidget,
    );
  });

  testWidgets('List — Split mode joins items with newline', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'List');

    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).last, 'BTC, ETH, SOL');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BTC\nETH\nSOL'), findsOneWidget);
  });
}
