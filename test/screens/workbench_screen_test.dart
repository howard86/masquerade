import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<void> _pumpWorkbench(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp(isWebOverride: false, skipSplash: true));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(CupertinoTextField).first, text);
  await tester.pump();
}

Finder _semantics(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('shows automatic empty, artifact, search, and unknown states', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);

    expect(_semantics('Empty Workbench'), findsOneWidget);
    expect(find.bySemanticsLabel('Paste'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan QR'), findsOneWidget);
    expect(find.text('CURRENT SESSION'), findsOneWidget);
    expect(find.text('SAVED WORKFLOWS'), findsOneWidget);

    await _enter(tester, '{"ok":true}');
    expect(find.text('Artifact detected'), findsOneWidget);
    expect(find.text('TOOL SUGGESTIONS'), findsOneWidget);
    expect(_semantics('Open JSON / YAML / TOML'), findsOneWidget);

    await _enter(tester, 'uuid');
    expect(find.text('Tool search'), findsOneWidget);
    expect(_semantics('Open UUID'), findsOneWidget);

    await _enter(tester, 'unrecognized prose value');
    expect(find.text('Unknown text'), findsOneWidget);
    expect(
      _semantics('Unknown text. Open as text or send to a tool.'),
      findsOneWidget,
    );
  });

  testWidgets('unknown text opens inline or routes to a chosen tool', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    const String input = '  unrecognized prose value  ';
    await _enter(tester, input);

    await tester.tap(find.text('Open as text'));
    await tester.pump();
    expect(find.text('TEXT'), findsOneWidget);
    expect(_semantics('Opened text: $input'), findsOneWidget);

    await tester.tap(find.text('Send to tool'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('UUID').last);
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'uuid');
    expect(route.seed, input);
  });

  testWidgets('Workbench input never reorders the Library catalog', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    await _enter(tester, '{"ok":true}');

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();

    final List<String> ids = tester
        .widgetList<ToolGridCard>(find.byType(ToolGridCard))
        .map((ToolGridCard card) => card.descriptor.id)
        .toList();
    expect(ids, UtilityCatalog.all.map((UtilityDescriptor tool) => tool.id));
  });

  testWidgets('suggestions open the detected tool with the captured input', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    await _enter(tester, '{"ok":true}');

    await tester.tap(find.text('JSON / YAML / TOML'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsOneWidget);
    expect(
      tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .any(
            (CupertinoTextField field) =>
                field.controller?.text == '{"ok":true}',
          ),
      isTrue,
    );
  });
}
