import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/widgets/mq/mq_input.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/mq/mq_status.dart';

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

  testWidgets(
    'Color — unparseable input surfaces error via MqInput.error/MqStatus, '
    'not an MqMonoCell',
    (WidgetTester tester) async {
      await pumpHomeAndOpen(tester, 'Color');

      await tester.enterText(find.byType(EditableText).last, 'not a color');
      await tester.pumpAndSettle(kDebouncePump);

      // Precise parser message is preserved and routed to the standard surface:
      // the MqInput's `error` slot and an MqStatus(danger) banner.
      expect(find.textContaining('Could not parse color'), findsWidgets);

      final MqInput input = tester.widget<MqInput>(find.byType(MqInput));
      expect(input.error, contains('Could not parse color'));

      expect(find.byType(MqStatus), findsWidgets);

      // The error is no longer rendered in an MqMonoCell labeled 'Error'.
      expect(find.text('Error'), findsNothing);

      // Output cells are gone while errored.
      expect(find.text('HEX'), findsNothing);
    },
  );

  testWidgets('Color — recovering from an error restores the output cells', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Color');

    await tester.enterText(find.byType(EditableText).last, 'not a color');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.byType(MqStatus), findsWidgets);

    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.pumpAndSettle(kDebouncePump);

    final MqInput input = tester.widget<MqInput>(find.byType(MqInput));
    expect(input.error, isNull);
    expect(_outputCell('#FF0000'), findsOneWidget);
    expect(find.text('HEX'), findsOneWidget);
    expect(find.text('RGB'), findsOneWidget);
    expect(find.text('HSL'), findsOneWidget);
    expect(find.text('OKLCH'), findsOneWidget);
  });
}
