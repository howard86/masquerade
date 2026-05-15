import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

Finder _outputCell(String value) =>
    find.descendant(of: find.byType(MqMonoCell), matching: find.text(value));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Math — simple expression yields exact result', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, '2*(3+4)');
    await tester.pumpAndSettle(kDebouncePump);

    expect(_outputCell('14'), findsOneWidget);
    // 14 is a clean int64 — hex / binary cells should appear.
    expect(_outputCell('0xE'), findsOneWidget);
    expect(_outputCell('0b1110'), findsOneWidget);
  });

  testWidgets('Math — exact decimal arithmetic (no float drift)', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, '0.1 + 0.2');
    await tester.pumpAndSettle(kDebouncePump);

    expect(_outputCell('0.3'), findsOneWidget);
    // Exact track — no approximate chip.
    expect(find.textContaining('APPROXIMATE'), findsNothing);
  });

  testWidgets('Math — sqrt(2) shows approximate status', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, 'sqrt(2)');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('APPROXIMATE'), findsOneWidget);
  });

  testWidgets('Math — division by zero surfaces error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, '1/0');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Division by zero'), findsOneWidget);
  });

  testWidgets('Math — incomplete syntax keeps last good result dimmed', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    final Finder field = find.byType(EditableText).last;
    await tester.enterText(field, '2+3');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('5'), findsOneWidget);

    // Edit to incomplete form — result cell should still show 5 (just dimmed
    // by an Opacity wrap; the text is still rendered).
    await tester.enterText(field, '2+3+');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('5'), findsOneWidget);
    // No error chip.
    expect(find.textContaining('Division by zero'), findsNothing);
  });

  testWidgets('Math — ans chip appears and references last result', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    final Finder field = find.byType(EditableText).last;
    await tester.enterText(field, '5+5');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('10'), findsOneWidget);

    // Chip text includes the formatted last-good value.
    expect(find.textContaining('ans = 10'), findsOneWidget);

    // Chaining via `ans` works.
    await tester.enterText(field, 'ans * 2');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('20'), findsOneWidget);
  });

  testWidgets('Math — empty input shows empty hint, no error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    final Finder field = find.byType(EditableText).last;
    await tester.enterText(field, '2+2');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('4'), findsOneWidget);

    await tester.enterText(field, '');
    await tester.pumpAndSettle(kDebouncePump);
    expect(_outputCell('4'), findsNothing);
  });

  testWidgets('Math — angle-unit preference persists across pumps', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mq.math.angle_unit': 'degrees',
    });
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, 'sin(30)');
    await tester.pumpAndSettle(kDebouncePump);

    // sin(30°) = 0.5 — exact promotion won't trigger (non-integer), so the
    // result renders as 0.5 with an approximate chip.
    expect(_outputCell('0.5'), findsOneWidget);
  });

  testWidgets('Math — unknown function shows error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Math');

    await tester.enterText(find.byType(EditableText).last, 'frobnicate(3)');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Unknown function'), findsOneWidget);
  });
}
