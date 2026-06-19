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

  testWidgets('Color — default seed renders HEX/RGB/HSL/OKLCH cells', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    // Seed value `#00B8C4` is set in `ColorScreen.initState`.
    expect(_outputCell('#00B8C4'), findsOneWidget);
    expect(find.text('HEX'), findsOneWidget);
    expect(find.text('RGB'), findsOneWidget);
    expect(find.text('HSL'), findsOneWidget);
    expect(find.text('OKLCH'), findsOneWidget);
    expect(find.text('WCAG CONTRAST'), findsOneWidget);
  });

  testWidgets('Color — rgb() input updates HEX cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    await tester.enterText(find.byType(EditableText).last, 'rgb(255, 0, 0)');
    await tester.pumpAndSettle(kDebouncePump);

    expect(_outputCell('#FF0000'), findsOneWidget);
    expect(_outputCell('rgb(255, 0, 0)'), findsOneWidget);
  });

  testWidgets('Color — pure white passes AA contrast vs black', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    await tester.enterText(find.byType(EditableText).last, '#FFFFFF');
    await tester.pumpAndSettle(kDebouncePump);

    // White vs black is 21:1, so both contrast tiles render the AA badge.
    expect(find.text('AA'), findsWidgets);
  });

  testWidgets('Color — unparseable input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    await tester.enterText(find.byType(EditableText).last, 'not a color');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Could not parse color'), findsOneWidget);
  });

  testWidgets('Color — Copy all writes every color form to the clipboard', (
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

    await pumpHomeAndOpen(tester, 'Color');

    await tester.enterText(find.byType(EditableText).last, 'rgb(255, 0, 0)');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('#FF0000')); // HEX
    expect(written, contains('rgb(255, 0, 0)')); // RGB
    expect(written, contains('hsl(0, 100%, 50%)')); // HSL
    expect(written, contains('oklch(')); // OKLCH

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Color — Copy all is hidden when input is unparseable', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    // The cold seed renders output, so Copy all is shown initially.
    expect(find.text('Copy all'), findsOneWidget);

    // An unparseable color clears the output → the center action hides.
    await tester.enterText(find.byType(EditableText).last, 'not a color');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);
  });
}
