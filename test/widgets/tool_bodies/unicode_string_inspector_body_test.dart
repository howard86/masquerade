import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/tool_bodies/unicode_string_inspector_body.dart';

import '_helpers.dart';

void main() {
  testWidgets('shows hidden characters, clusters, code points, and bytes', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const UnicodeStringInspectorBody(initialInput: '👨‍👩‍👧‍👦\u200b'),
      340,
    );

    expect(find.textContaining('2 graphemes'), findsOneWidget);
    expect(find.textContaining('U+1F468 U+200D'), findsOneWidget);
    expect(find.textContaining('ZERO WIDTH JOINER'), findsWidgets);
    expect(find.textContaining('ZERO WIDTH SPACE'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normalization changes input only after explicit Apply', (
    WidgetTester tester,
  ) async {
    const String input = 'e\u0301';
    await pumpBodyAtWidth(
      tester,
      const UnicodeStringInspectorBody(initialInput: input),
      340,
    );

    expect(_input(tester), input);
    final Finder apply = find.widgetWithText(MqButton, 'Apply NFC');
    expect(apply, findsOneWidget);
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(_input(tester), 'é');
    expect(find.widgetWithText(MqButton, 'Apply NFC'), findsNothing);
  });

  testWidgets('normalization previews replace bidi controls with markers', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const UnicodeStringInspectorBody(initialInput: 'abc\u202egpj'),
      340,
    );

    expect(find.textContaining('RIGHT-TO-LEFT OVERRIDE'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.contains('\u202e') ?? false),
      ),
      findsNothing,
    );
    expect(_input(tester), 'abc\u202egpj');
  });

  testWidgets('routes normalized text to Diff and UTF-8 integers to Bytes', (
    WidgetTester tester,
  ) async {
    String? toolId;
    String? routed;
    await pumpBodyAtWidth(
      tester,
      UnicodeStringInspectorBody(
        initialInput: 'e\u0301',
        onSwitchTool: (UtilityDescriptor tool, String input) {
          toolId = tool.id;
          routed = input;
        },
      ),
      340,
    );

    final Finder diff = find.widgetWithText(MqButton, 'NFC → Diff');
    await tester.ensureVisible(diff);
    await tester.tap(diff);
    expect(toolId, 'diff');
    expect(routed, 'é');

    final Finder bytes = find.widgetWithText(MqButton, 'UTF-8 → Bytes');
    await tester.ensureVisible(bytes);
    await tester.tap(bytes);
    expect(toolId, 'bytes');
    expect(routed, '101 204 129');
  });

  testWidgets('large single cluster stays bounded at 340 px and 2x text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final String input = 'a${'\u0301' * 512}';

    await pumpBodyAtWidth(
      tester,
      UnicodeStringInspectorBody(initialInput: input),
      340,
    );

    expect(find.text('GRAPHEME 1'), findsOneWidget);
    expect(find.textContaining('513 code points'), findsWidgets);
    expect(find.textContaining('code units)'), findsWidgets);
    expect(
      find.textContaining('PER-GRAPHEME DETAILS ARE BOUNDED'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables expanded Bytes routing above 64 KiB', (
    WidgetTester tester,
  ) async {
    final String input = List<String>.filled(
      1000,
      'a${'\u0301' * 40}',
    ).join(' ');
    await pumpBodyAtWidth(
      tester,
      UnicodeStringInspectorBody(
        initialInput: input,
        onSwitchTool: (_, _) => fail('oversized input must not route'),
      ),
      340,
    );

    expect(
      find.textContaining('BYTES ROUTING IS LIMITED TO 64 KIB'),
      findsOneWidget,
    );
    final MqButton button = tester.widget<MqButton>(
      find.widgetWithText(MqButton, 'UTF-8 → Bytes'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

String _input(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;
