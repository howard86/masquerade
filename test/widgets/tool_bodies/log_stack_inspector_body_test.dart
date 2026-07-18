import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';
import 'package:masquerade/widgets/tool_bodies/log_stack_inspector_body.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';

import '_helpers.dart';

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders and copies only redacted events', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const LogStackInspectorBody(
        initialInput: 'ERROR Authorization: Bearer raw-secret\nINFO next safe',
      ),
      340,
    );

    expect(find.textContaining('LOCAL INSPECTION ONLY'), findsOneWidget);
    expect(find.textContaining(SensitiveDataPolicy.mask), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data?.contains('raw-secret') == true,
      ),
      findsNothing,
    );
    expect(find.widgetWithText(MqButton, 'Copy event'), findsNWidgets(2));
    expect(find.widgetWithText(MqButton, 'Share event'), findsNWidgets(2));
    expect(find.textContaining('raw export', findRichText: true), findsNothing);

    await tester.tap(find.widgetWithText(MqButton, 'Copy event').first);
    await tester.pump();
    expect(clipboardText, contains(SensitiveDataPolicy.mask));
    expect(clipboardText, isNot(contains('raw-secret')));
  });

  testWidgets('search and level filters retain safe event order', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const LogStackInspectorBody(
        initialInput: 'INFO alpha first\nERROR beta\nWARN alpha last',
      ),
      340,
    );

    await tester.enterText(find.byType(EditableText).last, 'alpha');
    await tester.pump();
    expect(_rendered('INFO alpha first'), findsOneWidget);
    expect(_rendered('WARN alpha last'), findsOneWidget);
    expect(_rendered('ERROR beta'), findsNothing);

    await tester.tap(find.widgetWithText(MqButton, 'WARN'));
    await tester.pump();
    expect(_rendered('INFO alpha first'), findsNothing);
    expect(_rendered('WARN alpha last'), findsOneWidget);
  });

  testWidgets(
    'bounds event rendering while full filtered export stays enabled',
    (WidgetTester tester) async {
      final String input = List<String>.generate(
        60,
        (int index) => index == 59
            ? 'INFO event-59 token=raw-page-secret'
            : 'INFO event-$index',
      ).join('\n');
      await pumpBodyAtWidth(
        tester,
        LogStackInspectorBody(initialInput: input),
        340,
      );

      expect(find.textContaining('SHOWING 50 OF 60'), findsOneWidget);
      expect(_rendered('event-49'), findsOneWidget);
      expect(_rendered('event-59'), findsNothing);
      expect(find.widgetWithText(MqButton, 'Copy filtered'), findsOneWidget);
      await tester.tap(find.widgetWithText(MqButton, 'Copy filtered'));
      await tester.pump();
      expect(clipboardText, contains('event-59'));
      expect(clipboardText, contains(SensitiveDataPolicy.mask));
      expect(clipboardText, isNot(contains('raw-page-secret')));
      final Finder more = find.widgetWithText(MqButton, 'Show 50 more');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      expect(_rendered('event-59'), findsOneWidget);
    },
  );

  testWidgets('routes every safe artifact with protected lineage rules', (
    WidgetTester tester,
  ) async {
    final List<String> routed = <String>[];
    const String input =
        'INFO https://one.example https://two.example token=raw-secret';
    await pumpBodyAtWidth(
      tester,
      LogStackInspectorBody(
        key: const ValueKey<String>('sensitive-unprotected'),
        initialInput: input,
        onSwitchTool: (_, String value) => routed.add(value),
      ),
      340,
    );
    expect(find.textContaining('Open artifact'), findsNothing);

    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: true,
        child: LogStackInspectorBody(
          key: const ValueKey<String>('sensitive-protected'),
          initialInput: input,
          onSwitchTool: (_, String value) => routed.add(value),
        ),
      ),
      340,
    );
    expect(find.widgetWithText(MqButton, 'Open artifact 1'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Open artifact 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(MqButton, 'Open artifact 2'));
    expect(routed.single, 'https://two.example');

    routed.clear();
    await pumpBodyAtWidth(
      tester,
      LogStackInspectorBody(
        key: const ValueKey<String>('safe'),
        initialInput: 'INFO https://safe.example',
        onSwitchTool: (_, String value) => routed.add(value),
      ),
      340,
    );
    await tester.tap(
      find.widgetWithText(MqButton, 'Open in Artifact Inspector'),
    );
    expect(routed.single, 'https://safe.example');

    await pumpBodyAtWidth(
      tester,
      LogStackInspectorBody(
        key: const ValueKey<String>('placeholders'),
        initialInput:
            '[TRUNCATED JSON]\n-----BEGIN PRIVATE KEY-----\nhidden\n-----END PRIVATE KEY-----',
        onSwitchTool: (_, String value) => routed.add(value),
      ),
      340,
    );
    expect(find.textContaining('Open in Artifact Inspector'), findsNothing);
  });

  testWidgets('routes four mixed safe candidates in appearance order', (
    WidgetTester tester,
  ) async {
    final List<String> routed = <String>[];
    const List<String> artifacts = <String>[
      '550e8400-e29b-41d4-a716-446655440000',
      'SGVsbG8gV29ybGQ=',
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'hello%20world',
    ];
    await pumpBodyAtWidth(
      tester,
      LogStackInspectorBody(
        initialInput:
            'INFO ${artifacts[0]} ${artifacts[1]} ${artifacts[2]} ${artifacts[3]}',
        onSwitchTool: (_, String value) => routed.add(value),
      ),
      340,
    );
    for (int index = 1; index <= 4; index++) {
      final Finder button = find.widgetWithText(
        MqButton,
        'Open artifact $index',
      );
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
    }
    expect(routed, artifacts);
  });

  testWidgets('populated tool stays accessible at 340px and 2x text', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await pumpBodyAtWidth(
      tester,
      const LogStackInspectorBody(
        initialInput: '2026-07-18T09:10:11.123456+08:00 ERROR failure',
      ),
      340,
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is MqInput &&
            widget.semanticsLabel == 'Search redacted log events',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is MqButton && widget.semanticsLabel == 'Add ERROR filter',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large single event uses bounded preview and finds late matches',
    (WidgetTester tester) async {
      final String input = <String>[
        'ERROR failed',
        ...List<String>.generate(
          9000,
          (int index) =>
              '  at frame-$index ${index == 8999 ? 'late-needle' : ''}',
        ),
      ].join('\n');
      await pumpBodyAtWidth(
        tester,
        LogStackInspectorBody(initialInput: input),
        340,
      );

      expect(_rendered('PREVIEW TRUNCATED'), findsOneWidget);
      expect(find.widgetWithText(MqButton, 'Show more event'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'late-needle');
      await tester.pump();
      expect(_rendered('late-needle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unicode search and preview boundaries stay valid', (
    WidgetTester tester,
  ) async {
    final String input = 'ERROR ${'a' * 8185}😀İstanbul';
    await pumpBodyAtWidth(
      tester,
      LogStackInspectorBody(initialInput: input),
      340,
    );
    await tester.enterText(find.byType(EditableText).last, 'İSTANBUL');
    await tester.pump();
    expect(_rendered('İstanbul'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog and state surfaces keep the tool non-persistent', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor tool = UtilityCatalog.byId('log_stack_inspector');
    expect(tool.sensitivity, UtilitySensitivity.sensitive);
    expect(tool.historyPolicy, HistoryPolicy.disabled);
    expect(tool.liveLinkTypes, isEmpty);
    expect(
      SensitiveDataPolicy.persistedValue(
        'INFO token=never-save',
        utilityId: tool.id,
      ),
      isNull,
    );

    final HistoryController history = HistoryController();
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: history,
            child: const SingleChildScrollView(child: LogStackInspectorBody()),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(EditableText).first,
      'ERROR password=never-save',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(history.entries, isEmpty);
  });
}

Finder _rendered(String value) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Text &&
      (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(value),
);
