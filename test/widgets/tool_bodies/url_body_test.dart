import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/url_parser.dart';
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

  testWidgets('URL — editing a query value rebuilds the encoded query', (
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

    // The parsed pairs seed the editable table; the rebuilt query mirrors them.
    expect(find.text('q=cats&n=10'), findsOneWidget);

    // Edit the first value field (currently 'cats') to a value that needs
    // percent-encoding, and confirm the rebuilt query re-encodes it live and
    // round-trips through buildQuery.
    final Finder valueField = find.byWidgetPredicate(
      (Widget w) => w is EditableText && w.controller.text == 'cats',
    );
    expect(valueField, findsOneWidget);
    await tester.enterText(valueField, 'a b&c');
    await tester.pump();

    final String expected = UrlParser.buildQuery(<QueryPair>[
      const QueryPair('q', 'a b&c'),
      const QueryPair('n', '10'),
    ]);
    expect(expected, 'q=a+b%26c&n=10');
    expect(find.text(expected), findsOneWidget);
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
