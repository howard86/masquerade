import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/url_parser.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
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

  testWidgets('URL — adding a query pair rebuilds the encoded query', (
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

    expect(find.text('Add pair'), findsOneWidget);
    await tester.tap(find.text('Add pair'));
    await tester.pump();

    // The new row's Key/Value fields are appended last, after the existing
    // two rows (URL input field + 2 rows × 2 fields = 5 EditableTexts before).
    final List<Element> fields = find.byType(EditableText).evaluate().toList();
    expect(fields.length, 7);
    await tester.enterText(find.byWidget(fields[5].widget), 'x');
    await tester.pump();
    await tester.enterText(find.byWidget(fields[6].widget), 'y');
    await tester.pump();

    final String expected = UrlParser.buildQuery(<QueryPair>[
      const QueryPair('q', 'cats'),
      const QueryPair('n', '10'),
      const QueryPair('x', 'y'),
    ]);
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('URL — removing a query pair rebuilds the encoded query', (
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

    expect(find.bySemanticsLabel('Remove n'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Remove n'));
    await tester.pump();

    final String expected = UrlParser.buildQuery(<QueryPair>[
      const QueryPair('q', 'cats'),
    ]);
    expect(find.text(expected), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('URL — Swap carries an edited query pair through', (
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

    // Edit the 'q' value from 'cats' to 'dogs' in the query table.
    final Finder valueField = find.byWidgetPredicate(
      (Widget w) => w is EditableText && w.controller.text == 'cats',
    );
    expect(valueField, findsOneWidget);
    await tester.enterText(valueField, 'dogs');
    await tester.pump();

    // Swap flips mode and feeds the output back as input; without the fix
    // the edit is dropped and the swapped-in text still says 'cats'.
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('dogs'), findsWidgets);
    expect(find.textContaining('cats'), findsNothing);
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

  testWidgets('URL — decoded credentials keep protection', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'URL');
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).last,
      '%7B%22password%22%3A%22raw-credential-fixture%22%7D',
    );
    await tester.pumpAndSettle(kDebouncePump);

    final MqMonoCell output = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .firstWhere((MqMonoCell cell) => cell.label == 'Decoded');
    expect(output.sensitive, isTrue);
    expect(find.bySemanticsLabel('Copy Decoded'), findsOneWidget);
  });
}
