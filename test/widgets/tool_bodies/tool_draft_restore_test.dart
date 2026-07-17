import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/tool_draft_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_chip.dart';
import 'package:masquerade/widgets/mq/mq_dropdown.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/json_body.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> openTool(WidgetTester tester, String label) async {
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    final Finder tile = find.text(label).last;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, ToolDraftController drafts) async {
    await tester.binding.setSurfaceSize(kDetailSurfaceSize);
    await tester.pumpWidget(
      MyApp(toolDraftController: drafts, skipSplash: true),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('JSON draft survives navigation and a fresh app controller', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ToolDraftController drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '{"draft":1}');
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pretty JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minified JSON').last);
    await tester.pumpAndSettle(kDebouncePump);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTool(tester, 'JSON / YAML / TOML');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .controller
          .text,
      '{"draft":1}',
    );
    expect(find.text('Minified JSON'), findsOneWidget);
    expect(
      tester
          .widgetList<MqDropdown<SourceFormat>>(
            find.byType(MqDropdown<SourceFormat>),
          )
          .first
          .selected,
      SourceFormat.json,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'JSON / YAML / TOML');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .controller
          .text,
      '{"draft":1}',
    );
    expect(find.text('Minified JSON'), findsOneWidget);
    expect(
      tester
          .widgetList<MqDropdown<SourceFormat>>(
            find.byType(MqDropdown<SourceFormat>),
          )
          .first
          .selected,
      SourceFormat.json,
    );
  });

  testWidgets('Diff inputs and mode survive a fresh app controller', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ToolDraftController drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'Diff');

    await tester.enterText(find.byType(EditableText).first, 'before');
    await tester.enterText(find.byType(EditableText).last, 'after');
    await tester.tap(find.text('Word highlight'));
    await tester.tap(find.text('Ignore whitespace'));
    await tester.pumpAndSettle(kDebouncePump);

    await tester.pumpWidget(const SizedBox.shrink());
    drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'Diff');
    final List<EditableText> fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields.first.controller.text, 'before');
    expect(fields.last.controller.text, 'after');
    final Map<String, bool> selected = <String, bool>{
      for (final MqChip chip in tester.widgetList<MqChip>(find.byType(MqChip)))
        chip.label: chip.selected,
    };
    expect(selected['Word highlight'], isFalse);
    expect(selected['Ignore whitespace'], isTrue);
  });

  testWidgets('Generator restores config without persisting generated output', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ToolDraftController drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'Generator');

    await tester.tap(find.text('Token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '24');
    await tester.pumpAndSettle();
    final String generated = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .firstWhere((MqMonoCell cell) => cell.label == 'Token')
        .value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ToolDraftController.storageKey),
      isNot(contains(generated)),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    drafts = await ToolDraftController.load();
    await pumpApp(tester, drafts);
    await openTool(tester, 'Generator');
    expect(find.text('Token'), findsWidgets);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .controller
          .text,
      '24',
    );
    final String regenerated = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .firstWhere((MqMonoCell cell) => cell.label == 'Token')
        .value;
    expect(regenerated, isNot(generated));
  });

  testWidgets('explicit seed wins while saved JSON selection still restores', (
    WidgetTester tester,
  ) async {
    final ToolDraftController drafts = await ToolDraftController.load();
    await drafts.saveJson(
      input: '{"stale":true}',
      source: 'json',
      target: 'minifiedJson',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: ToolDraftScope(
              controller: drafts,
              child: const MobileSessionRouteScope(
                addNext: false,
                protectedSession: false,
                child: JSONBody(initialInput: '{"fresh":true}'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '{"fresh":true}',
    );
    expect(find.text('Minified JSON'), findsOneWidget);
  });

  testWidgets('body without mobile route scope cannot read or write drafts', (
    WidgetTester tester,
  ) async {
    final ToolDraftController drafts = await ToolDraftController.load();
    await drafts.saveJson(
      input: '{"mobile":true}',
      source: 'json',
      target: 'prettyJson',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: ToolDraftScope(controller: drafts, child: const JSONBody()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final EditableText input = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(input.controller.text, isEmpty);

    await tester.enterText(find.byType(EditableText), '{"desktop":true}');
    await tester.pumpAndSettle(kDebouncePump);
    expect(drafts.json!.input, '{"mobile":true}');
  });

  testWidgets('content-safe protected lineage never overwrites a JSON draft', (
    WidgetTester tester,
  ) async {
    final ToolDraftController drafts = await ToolDraftController.load();
    await drafts.saveJson(
      input: '{"saved":true}',
      source: 'json',
      target: 'prettyJson',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: ToolDraftScope(
              controller: drafts,
              child: const MobileSessionRouteScope(
                addNext: true,
                protectedSession: true,
                child: JSONBody(initialInput: '{"sub":"user"}'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(kDebouncePump);
    await tester.enterText(find.byType(EditableText), '{"sub":"changed"}');
    await tester.pumpAndSettle(kDebouncePump);

    expect(drafts.json!.input, '{"saved":true}');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ToolDraftController.storageKey),
      isNot(contains('changed')),
    );
  });

  testWidgets('direct sensitive JSON typing removes only the JSON draft', (
    WidgetTester tester,
  ) async {
    final ToolDraftController drafts = await ToolDraftController.load();
    await drafts.saveJson(
      input: '{"saved":true}',
      source: 'json',
      target: 'prettyJson',
    );
    await drafts.saveDiff(
      a: 'safe a',
      b: 'safe b',
      wordHighlight: true,
      ignoreWhitespace: false,
    );
    await drafts.saveGenerator(
      const GeneratorToolDraft(
        mode: 'uuid',
        length: 20,
        bytes: 16,
        lower: true,
        upper: true,
        digits: true,
        symbols: true,
        tokenFormat: 'hex',
        uuidVersion: 'v7',
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: ToolDraftScope(
              controller: drafts,
              child: const MobileSessionRouteScope(
                addNext: false,
                protectedSession: false,
                child: JSONBody(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(kDebouncePump);
    await tester.enterText(
      find.byType(EditableText),
      '{"access_token":"do-not-save"}',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(drafts.json, isNull);
    expect(drafts.diff!.b, 'safe b');
    expect(drafts.generator!.uuidVersion, 'v7');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ToolDraftController.storageKey),
      isNot(contains('do-not-save')),
    );
  });
}
