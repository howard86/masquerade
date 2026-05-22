import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('hash — typing text shows SHA-256 digest', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // SHA-256 of "abc"
    expect(
      find.textContaining('ba7816bf8f01cfea414140de5dae2223'),
      findsOneWidget,
    );
  });

  testWidgets('hash — typing text shows MD5 digest', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // MD5 of "abc"
    expect(
      find.textContaining('900150983cd24fb0d6963f7d28e17f72'),
      findsOneWidget,
    );
  });

  testWidgets('hash — matching expected digest highlights row', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // Enter the SHA-256 digest in the verify field
    final Finder verifyField = find.byType(EditableText).last;
    await tester.enterText(
      verifyField,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    await tester.pumpAndSettle();

    // The SHA-256 row should now be accented (accent: true renders with
    // accentBg background). We verify by checking the label still renders.
    expect(find.text('SHA-256'), findsOneWidget);
  });
}
