import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Bytes — decode plain space-separated integers to UTF-8 + hex', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText), '72 101 108 108 111');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('48 65 6c 6c 6f'), findsOneWidget);
  });

  testWidgets('Bytes — decode bracketed comma list', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText), '[72, 105]');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Hi'), findsOneWidget);
    expect(find.text('48 69'), findsOneWidget);
  });

  testWidgets('Bytes — encode shows space, brackets, and hex simultaneously', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.tap(find.text('Encode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'Hi');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('72 105'), findsOneWidget);
    expect(find.text('[72, 105]'), findsOneWidget);
    expect(find.text('48 69'), findsOneWidget);
  });

  testWidgets('Bytes — out-of-range integer surfaces parser error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText), '300 1 2');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('out of range'), findsOneWidget);
  });

  testWidgets('Bytes — invalid UTF-8 still renders hex preview', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    // 0xC8 0xC8 are valid byte values but not a valid UTF-8 sequence.
    await tester.enterText(find.byType(EditableText), '200 200');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Invalid UTF-8'), findsOneWidget);
    expect(find.text('c8 c8'), findsOneWidget);
  });
}
