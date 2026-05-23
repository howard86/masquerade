import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('generator — opens in password mode with output and controls', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Generator');

    // 'Password' appears as both the mode segment and the output cell label.
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('a-z'), findsOneWidget);
    expect(find.text('!@#'), findsOneWidget);
  });

  testWidgets('generator — switching to UUID mode shows a v4 output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Generator');

    await tester.tap(find.text('UUID'));
    await tester.pumpAndSettle();

    expect(find.text('UUID v4'), findsOneWidget);
  });

  testWidgets('generator — disabling all character sets shows the empty hint', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Generator');

    for (final String chip in <String>['a-z', 'A-Z', '0-9', '!@#']) {
      await tester.tap(find.text(chip));
      await tester.pumpAndSettle();
    }

    expect(find.text('Enable at least one character set.'), findsOneWidget);
  });

  testWidgets('generator — Regenerate does not throw', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Generator');

    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
