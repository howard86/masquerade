import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

import '_helpers.dart';

Finder _outputCell(String value) =>
    find.descendant(of: find.byType(MqMonoCell), matching: find.text(value));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Number Base — decimal input emits all four representations', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '255');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 10'), findsOneWidget);
    expect(_outputCell('255'), findsOneWidget);
    expect(_outputCell('0xFF'), findsOneWidget);
    expect(_outputCell('0o377'), findsOneWidget);
    expect(_outputCell('0b11111111'), findsOneWidget);
  });

  testWidgets('Number Base — 0x-prefixed hex detects base 16', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '0xFF');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 16'), findsOneWidget);
    expect(_outputCell('255'), findsOneWidget);
  });

  testWidgets('Number Base — 0b-prefixed binary detects base 2', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '0b1010');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('BASE 2'), findsOneWidget);
    expect(_outputCell('10'), findsOneWidget);
  });

  testWidgets('Number Base — non-numeric input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, 'xyz!');
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.textContaining('Could not parse as a number in any base'),
      findsOneWidget,
    );
  });

  testWidgets('Number Base — Copy all writes every base to the clipboard', (
    WidgetTester tester,
  ) async {
    final List<String> clipboardWrites = <String>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final Map<dynamic, dynamic> args = call.arguments as Map;
        clipboardWrites.add(args['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpHomeAndOpen(tester, 'Number Base');

    await tester.enterText(find.byType(EditableText).last, '255');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('255')); // decimal
    expect(written, contains('0xFF')); // hex
    expect(written, contains('0o377')); // octal
    expect(written, contains('0b11111111')); // binary

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Number Base — Copy all is hidden when there is no output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Number Base');

    // Empty input → no parsed result → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    // It appears once something parses…
    await tester.enterText(find.byType(EditableText).last, '255');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);

    // …and disappears again when the input is cleared.
    await tester.enterText(find.byType(EditableText).last, '');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);
  });
}
