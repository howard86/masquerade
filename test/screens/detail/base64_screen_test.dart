import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Base64 — encode mode produces standard base64 output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('aGVsbG8='), findsOneWidget);
  });

  testWidgets('Base64 — decode mode round-trips back to plain text', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'aGVsbG8=');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('Base64 — URL-safe chip flips +/ to -_', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    // ">>>" → bytes 0x3E×3 → standard "Pj4+", URL-safe "Pj4-".
    await tester.enterText(find.byType(EditableText), '>>>');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Pj4+'), findsOneWidget);

    await tester.tap(find.text('URL-safe'));
    await tester.pumpAndSettle();
    expect(find.text('Pj4-'), findsOneWidget);
  });

  testWidgets('Base64 — Strip-padding chip drops trailing =', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    // "h" → bytes [0x68] → "aA==", stripped "aA".
    await tester.enterText(find.byType(EditableText), 'h');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('aA=='), findsOneWidget);

    await tester.tap(find.text('Strip padding'));
    await tester.pumpAndSettle();
    expect(find.text('aA'), findsOneWidget);
  });

  testWidgets('Base64 — invalid decode input shows error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'not@valid');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Invalid base64'), findsOneWidget);
  });
}
