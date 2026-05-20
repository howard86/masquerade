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
}
