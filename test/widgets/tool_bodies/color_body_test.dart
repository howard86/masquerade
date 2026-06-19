import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/color_body.dart';

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

  testWidgets('Color — each palette swatch exposes a "Select #…" semantics '
      'label for screen readers', (WidgetTester tester) async {
    // Palette strip is canvas-only (wide width); pump at 640 so it renders.
    await pumpBodyAtWidth(tester, const ColorBody(), 640);

    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.pumpAndSettle(kDebouncePump);
    await tester.enterText(find.byType(EditableText).last, '#00FF00');
    await tester.pumpAndSettle(kDebouncePump);

    // Two distinct colors entered -> two semantically-labelled swatches.
    expect(find.bySemanticsLabel(RegExp('Select #')), findsNWidgets(2));
    expect(find.bySemanticsLabel('Select #FF0000'), findsOneWidget);
    expect(find.bySemanticsLabel('Select #00FF00'), findsOneWidget);
  });
}
