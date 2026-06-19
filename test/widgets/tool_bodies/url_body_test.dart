import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('URL — encode mode percent-escapes the input', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');

    await tester.enterText(find.byType(EditableText).last, 'a b&c');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('a%20b%26c'), findsOneWidget);
  });

  testWidgets('URL — decode mode round-trips back to plain text', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).last, 'a%20b%26c');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('a b&c'), findsOneWidget);
  });

  testWidgets('URL — decode renders parsed query pairs', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).last,
      'https://x.com/s?q=cats&n=10',
    );
    await tester.pumpAndSettle(kDebouncePump);

    // The Query section header plus a cell per pair (key as label, value shown).
    expect(find.text('QUERY'), findsOneWidget);
    expect(find.text('cats'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('URL — malformed decode input shows error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).last, '%ZZ');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Invalid percent-encoding'), findsOneWidget);
  });

  testWidgets('URL — empty input shows the empty hint', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');

    expect(find.textContaining('percent-encode'), findsOneWidget);
  });
}
