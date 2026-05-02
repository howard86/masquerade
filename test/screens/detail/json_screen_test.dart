import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('JSON — Pretty mode formats minified input with indent', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON');

    await tester.enterText(find.byType(EditableText), '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('PRETTY'), findsOneWidget);
    expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
  });

  testWidgets('JSON — Minify mode collapses whitespace', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON');

    await tester.enterText(find.byType(EditableText), '{ "a" : 1 }');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Minify'));
    await tester.pumpAndSettle();

    expect(find.text('MINIFY'), findsOneWidget);
    expect(find.text('{"a":1}'), findsOneWidget);
  });

  testWidgets('JSON — Tree mode renders key path lines', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON');

    await tester.enterText(find.byType(EditableText), '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Tree'));
    await tester.pumpAndSettle();

    expect(find.text('TREE'), findsOneWidget);
    expect(find.text('{\n  a: 1\n}'), findsOneWidget);
  });

  testWidgets('JSON — invalid input shows error badge with line/col', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON');

    await tester.enterText(find.byType(EditableText), '{');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('ERROR · LINE 1 COL'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
  });
}
