import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/tool_bodies/http_inspector_body.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';

import '_helpers.dart';

void main() {
  testWidgets('parses locally and only renders redacted previews/conversions', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const HttpInspectorBody(
        initialInput:
            "curl -H 'Authorization: Bearer raw-secret' 'https://example.com?a=1&token=query-secret'",
      ),
      340,
    );

    expect(find.textContaining('LOCAL INSPECTION ONLY'), findsOneWidget);
    expect(find.textContaining('[REDACTED]'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data?.contains('raw-secret') == true,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data?.contains('query-secret') == true,
      ),
      findsNothing,
    );
    expect(
      find.widgetWithText(MqButton, 'Copy redacted conversion'),
      findsOneWidget,
    );
    expect(find.widgetWithText(MqButton, 'Execute'), findsNothing);
    expect(find.widgetWithText(MqButton, 'Send'), findsNothing);
  });

  testWidgets('six converters remain usable at 2x text scale', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await pumpBodyAtWidth(
      tester,
      const HttpInspectorBody(
        initialInput: "curl 'https://example.com/health'",
      ),
      340,
    );

    for (final String label in <String>[
      'cURL',
      'Fetch',
      'Axios',
      'Python',
      'Go',
      'Rust',
    ]) {
      expect(find.widgetWithText(MqButton, label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('safe JSON body routes only with protected sensitive lineage', (
    WidgetTester tester,
  ) async {
    String? routed;
    const String input =
        "curl -H 'Authorization: Bearer raw-secret' -H 'Content-Type: application/json' --data-raw '{\"ok\":true}' 'https://example.com'";

    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: false,
        child: HttpInspectorBody(
          initialInput: input,
          onSwitchTool: (_, String value) => routed = value,
        ),
      ),
      340,
    );
    expect(_action('Add next step JSON / YAML / TOML'), findsNothing);

    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: true,
        child: HttpInspectorBody(
          initialInput: input,
          onSwitchTool: (_, String value) => routed = value,
        ),
      ),
      340,
    );
    final Finder action = _action('Add next step JSON / YAML / TOML');
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(routed, '{"ok":true}');
  });

  testWidgets('never records input or output history', (
    WidgetTester tester,
  ) async {
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
            child: const HttpInspectorBody(),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(EditableText),
      "curl 'https://example.com?token=never-save'",
    );
    await tester.pump(kDebouncePump);
    expect(history.entries, isEmpty);
  });

  testWidgets('safe form body routes as URL query data', (
    WidgetTester tester,
  ) async {
    String? routed;
    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: false,
        child: HttpInspectorBody(
          initialInput:
              "curl -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'a=1&b=2' 'https://example.com'",
          onSwitchTool: (_, String value) => routed = value,
        ),
      ),
      340,
    );
    final Finder action = _action('Add next step URL');
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(routed, '?a=1&b=2');
  });

  testWidgets('catalog exposes a sensitive desktop-capable tool', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor tool = UtilityCatalog.byId('http_inspector');
    expect(tool.sensitivity, UtilitySensitivity.sensitive);
    expect(tool.historyPolicy, HistoryPolicy.disabled);
    expect(tool.defaultCardWidth, CardWidthClass.wide);
    await pumpHomeAndOpen(tester, 'HTTP Inspector');
    expect(find.byType(HttpInspectorBody), findsOneWidget);
  });
}

Finder _action(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);
