import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openDiff(WidgetTester tester) => pumpHomeAndOpen(tester, 'Diff');

  testWidgets('Diff — empty state prompts for both inputs', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    expect(find.text('Paste or type into A and B to compare.'), findsOneWidget);
  });

  testWidgets('Diff — one-line change shows +1 / −1 summary', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    await tester.enterText(find.byType(EditableText).first, 'a\nb\nc');
    await tester.enterText(find.byType(EditableText).last, 'a\nB\nc');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
  });

  testWidgets('Diff — identical inputs report no differences', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    await tester.enterText(find.byType(EditableText).first, 'same\ntext');
    await tester.enterText(find.byType(EditableText).last, 'same\ntext');
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.text('No differences — A and B are identical.'),
      findsOneWidget,
    );
  });

  testWidgets('Diff — Word highlight toggles spans on the same diff', (
    WidgetTester tester,
  ) async {
    Finder row(String text, {required bool rich}) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          (rich
              ? widget.data == null && widget.textSpan?.toPlainText() == text
              : widget.data == text),
    );
    await openDiff(tester);
    await tester.enterText(find.byType(EditableText).first, 'the quick fox');
    await tester.enterText(find.byType(EditableText).last, 'the slow fox');
    await tester.pumpAndSettle(kDebouncePump);
    expect(row('the quick fox', rich: true), findsOneWidget);
    expect(row('the slow fox', rich: true), findsOneWidget);

    await tester.tap(find.text('Word highlight'));
    await tester.pump();
    expect(row('the quick fox', rich: false), findsOneWidget);
    expect(row('the slow fox', rich: false), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.text('Word highlight'));
    await tester.pump();
    expect(row('the quick fox', rich: true), findsOneWidget);
    expect(row('the slow fox', rich: true), findsOneWidget);
  });

  testWidgets('Diff — Ignore whitespace collapses spacing-only changes', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    await tester.enterText(
      find.byType(EditableText).first,
      '  hello   world  ',
    );
    await tester.enterText(find.byType(EditableText).last, 'hello world');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.text('Ignore whitespace'));
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.text('No differences — A and B are identical.'),
      findsOneWidget,
    );
  });

  testWidgets('Diff — action bar offers Swap instead of Paste', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    await tester.enterText(find.byType(EditableText).first, 'x');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Swap A↔B'), findsOneWidget);
    expect(find.text('Paste'), findsNothing);
  });

  testWidgets('Diff — collapse divider exposes an operable button to a11y', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);

    // A change at the very top and bottom with many identical lines between
    // them leaves a gap wider than the 3-line context window, so the middle
    // unchanged lines collapse behind a `_CollapseDivider`.
    final List<String> middle = List<String>.generate(20, (int i) => 'line $i');
    final String a = <String>['top', ...middle, 'bottom'].join('\n');
    final String b = <String>['TOP', ...middle, 'BOTTOM'].join('\n');
    await tester.enterText(find.byType(EditableText).first, a);
    await tester.enterText(find.byType(EditableText).last, b);
    await tester.pumpAndSettle(kDebouncePump);

    // The collapse control announces itself as a button with a descriptive,
    // state-aware label so a screen reader can find and operate it.
    final Finder divider = find.byWidgetPredicate(
      (Widget w) =>
          w is Semantics &&
          w.properties.button == true &&
          (w.properties.label ?? '').startsWith('Expand ') &&
          (w.properties.label ?? '').endsWith(' unchanged lines'),
    );
    expect(divider, findsOneWidget);
    expect(tester.getSize(divider).height, greaterThanOrEqualTo(44));
    final Rect dividerRect = tester.getRect(divider);
    for (int i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final BuildContext? context = FocusManager.instance.primaryFocus?.context;
      final RenderObject? renderObject = context?.findRenderObject();
      if (renderObject is RenderBox &&
          dividerRect.contains(renderObject.localToGlobal(Offset.zero))) {
        break;
      }
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(divider, findsNothing);
    expect(find.text('line 10'), findsWidgets);
  });

  testWidgets('Diff — a large diff renders lazily in a bounded list', (
    WidgetTester tester,
  ) async {
    await openDiff(tester);
    // 1,000 changed lines → 2,000 rows, well past the virtualization bound;
    // the last line is far wider than the viewport.
    final String wide = 'w' * 400;
    final String a = <String>[
      for (int i = 0; i < 1000; i++) 'old $i',
      wide,
    ].join('\n');
    final String b = <String>[
      for (int i = 0; i < 1000; i++) 'new $i',
      wide,
    ].join('\n');
    await tester.enterText(find.byType(EditableText).first, a);
    await tester.enterText(find.byType(EditableText).last, b);
    await tester.pumpAndSettle(kDebouncePump);

    final Finder list = find.byKey(const ValueKey<String>('diff-virtual-list'));
    expect(list, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('+1000'), findsOneWidget);
    // Only the rows in view are built, not all 2,000.
    final int built = find
        .byWidgetPredicate(
          (Widget w) =>
              w is Text &&
              (w.data?.startsWith('old ') ??
                  w.textSpan?.toPlainText().startsWith('old ') ??
                  false),
        )
        .evaluate()
        .length;
    expect(built, greaterThan(0));
    expect(built, lessThan(200));

    // The measured width covers the widest line, so the view scrolls
    // horizontally past the viewport.
    final ScrollableState horizontal = tester.state<ScrollableState>(
      find.ancestor(of: list, matching: find.byType(Scrollable)).first,
    );
    expect(horizontal.position.axis, Axis.horizontal);
    expect(horizontal.position.maxScrollExtent, greaterThan(0));

    // Scrolling the list reaches later rows.
    await tester.ensureVisible(list);
    await tester.pumpAndSettle();
    // The list is as wide as the widest line; drag from its visible corner.
    await tester.dragFrom(
      tester.getTopLeft(list) + const Offset(100, 100),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(find.text('old 0'), findsNothing);
  });
}
