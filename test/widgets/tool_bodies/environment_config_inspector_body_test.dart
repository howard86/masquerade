import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/tool_bodies/environment_config_inspector_body.dart';
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

  testWidgets('renders and copies only redacted normalized and conversions', (
    WidgetTester tester,
  ) async {
    const String secret = 'fixture-db-password';
    await pumpBodyAtWidth(
      tester,
      const EnvironmentConfigInspectorBody(
        initialInput: 'DB_PASSWORD=$secret\nPUBLIC_NAME=demo',
      ),
      340,
    );

    expect(find.textContaining('SECRETS MASKED'), findsOneWidget);
    expect(find.textContaining(SensitiveDataPolicy.mask), findsWidgets);
    expect(_rendered(secret), findsNothing);

    await tester.tap(find.widgetWithText(MqButton, 'Copy redacted'));
    await tester.pump();
    expect(clipboardText, contains(SensitiveDataPolicy.mask));
    expect(clipboardText, isNot(contains(secret)));

    final Finder copyJson = find.widgetWithText(MqButton, 'Copy JSON');
    await tester.ensureVisible(copyJson);
    await tester.tap(copyJson);
    await tester.pump();
    expect(clipboardText, contains('DB_PASSWORD'));
    expect(clipboardText, contains(SensitiveDataPolicy.mask));
    expect(clipboardText, isNot(contains(secret)));
  });

  testWidgets('sorts, reports duplicates, and compares safe values', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const EnvironmentConfigInspectorBody(
        initialInput: 'B=old\nA=one\nB=last',
      ),
      340,
    );

    expect(find.textContaining('DUPLICATE B ON LINES 1, 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(MqButton, 'Sort keys'));
    await tester.pump();
    await tester.tap(find.widgetWithText(MqButton, 'Copy redacted'));
    await tester.pump();
    expect(clipboardText, 'A=one\nB=old\nB=last');

    await tester.enterText(
      find.byType(EditableText).last,
      'A=one\nB=new\nC=added',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 ADDED'), findsOneWidget);
    expect(find.textContaining('1 REMOVED'), findsOneWidget);
    expect(find.textContaining('1 CHANGED'), findsOneWidget);
    expect(
      find.widgetWithText(MqButton, 'Copy full redacted diff'),
      findsOneWidget,
    );
  });

  testWidgets('routes typed JSON and Diff payloads with protected lineage', (
    WidgetTester tester,
  ) async {
    final List<(String, String)> routes = <(String, String)>[];
    await pumpBodyAtWidth(
      tester,
      EnvironmentConfigInspectorBody(
        key: const ValueKey<String>('safe'),
        initialInput: 'A=one\nB=two',
        onSwitchTool: (UtilityDescriptor tool, String value) =>
            routes.add((tool.id, value)),
      ),
      340,
    );
    final Finder openJson = find.widgetWithText(MqButton, 'Open in JSON').first;
    await tester.ensureVisible(openJson);
    await tester.tap(openJson);
    expect(routes.single.$1, 'json');
    expect(routes.single.$2, contains('"A": "one"'));

    await tester.enterText(find.byType(EditableText).last, 'A=changed\nB=two');
    await tester.pump(const Duration(milliseconds: 300));
    final Finder openDiff = find.widgetWithText(MqButton, 'Open A in Diff');
    await tester.ensureVisible(openDiff);
    await tester.tap(openDiff);
    expect(routes.last.$1, 'diff');
    expect(routes.last.$2, 'A=one\nB=two');

    routes.clear();
    await pumpBodyAtWidth(
      tester,
      EnvironmentConfigInspectorBody(
        key: const ValueKey<String>('protected'),
        initialInput: 'PASSWORD=route-secret\nA=one',
        onSwitchTool: (UtilityDescriptor tool, String value) =>
            routes.add((tool.id, value)),
      ),
      340,
    );
    expect(find.widgetWithText(MqButton, 'Open in JSON'), findsNothing);

    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: true,
        child: EnvironmentConfigInspectorBody(
          key: const ValueKey<String>('protected-chain'),
          initialInput: 'PASSWORD=route-secret\nA=one',
          onSwitchTool: (UtilityDescriptor tool, String value) =>
              routes.add((tool.id, value)),
        ),
      ),
      340,
    );
    final Finder protectedJson = find
        .widgetWithText(MqButton, 'Open in JSON')
        .first;
    await tester.ensureVisible(protectedJson);
    await tester.tap(protectedJson);
    expect(routes.single.$1, 'json');
    expect(routes.single.$2, contains(SensitiveDataPolicy.mask));
    expect(routes.single.$2, isNot(contains('route-secret')));
  });

  testWidgets('bounds 10k duplicate output and remains narrow at 2x text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final String input = List<String>.filled(
      10000,
      'LONG_KEY=value',
    ).join('\n');
    await pumpBodyAtWidth(
      tester,
      EnvironmentConfigInspectorBody(
        initialInput: input,
        onSwitchTool: (_, _) {},
      ),
      340,
    );

    expect(find.textContaining('(+9992 MORE)'), findsOneWidget);
    expect(find.textContaining('TOO LARGE TO ROUTE'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Open in JSON'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large unique conversion copies but cannot route downstream', (
    WidgetTester tester,
  ) async {
    final String input = List<String>.generate(
      1000,
      (int index) => 'KEY_$index=${'x' * 80}',
    ).join('\n');
    await pumpBodyAtWidth(
      tester,
      EnvironmentConfigInspectorBody(
        initialInput: input,
        onSwitchTool: (_, _) {},
      ),
      340,
    );

    expect(find.widgetWithText(MqButton, 'Copy JSON'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Open in JSON'), findsNothing);
    expect(find.textContaining('TOO LARGE TO ROUTE'), findsOneWidget);
    await tester.tap(find.widgetWithText(MqButton, 'Copy redacted'));
    await tester.pump();
    expect(clipboardText!.length, greaterThan(64 * 1024));

    await tester.enterText(find.byType(EditableText).last, 'KEY_0=changed');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MqButton, 'Open A in Diff'), findsNothing);
  });

  testWidgets('paginates distinct duplicate groups', (
    WidgetTester tester,
  ) async {
    final String input = <String>[
      for (int index = 0; index < 25; index++) ...<String>[
        'KEY_$index=first',
        'KEY_$index=second',
      ],
    ].join('\n');
    await pumpBodyAtWidth(
      tester,
      EnvironmentConfigInspectorBody(initialInput: input),
      340,
    );

    expect(find.textContaining('DUPLICATE KEY_19'), findsOneWidget);
    expect(find.textContaining('DUPLICATE KEY_20'), findsNothing);
    final Finder more = find.widgetWithText(
      MqButton,
      'Show 20 more duplicates',
    );
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(find.textContaining('DUPLICATE KEY_24'), findsOneWidget);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog and history keep config sessions non-persistent', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor tool = UtilityCatalog.byId(
      'environment_config_inspector',
    );
    expect(tool.sensitivity, UtilitySensitivity.sensitive);
    expect(tool.historyPolicy, HistoryPolicy.disabled);
    expect(tool.liveLinkTypes, isEmpty);
    expect(
      SensitiveDataPolicy.persistedValue('PUBLIC=value', utilityId: tool.id),
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
            child: const SingleChildScrollView(
              child: EnvironmentConfigInspectorBody(),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(EditableText).first,
      'PASSWORD=never-save',
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
