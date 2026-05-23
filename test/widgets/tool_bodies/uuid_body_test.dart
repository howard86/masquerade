import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('uuid — pasting dashed UUID shows Version and Canonical rows', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'UUID');

    await tester.enterText(
      find.byType(EditableText).first,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Canonical'), findsOneWidget);
  });

  testWidgets('uuid — tapping Generate v4 populates a value', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'UUID');

    await tester.tap(find.text('Generate v4'));
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Version'), findsOneWidget);
  });
}
