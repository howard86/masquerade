import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';

Widget _hostHome({required Widget Function(BuildContext) onPress}) {
  return CupertinoApp(
    builder: (BuildContext context, Widget? child) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: HistoryScope(
        controller: HistoryController(),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: Builder(
      builder: (BuildContext context) => CupertinoPageScaffold(
        child: Center(
          child: CupertinoButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push<void>(CupertinoPageRoute<void>(builder: onPress));
            },
            child: const Text('GO'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nav bar middle with descriptor name', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor d = UtilityCatalog.byId('json');
    await tester.pumpWidget(
      _hostHome(
        onPress: (_) => ToolDetailRoute(descriptor: d, seed: '{"a":1}'),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.text('JSON / YAML / TOML'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('seeds the body with the supplied input', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor d = UtilityCatalog.byId('json');
    await tester.pumpWidget(
      _hostHome(
        onPress: (_) => ToolDetailRoute(descriptor: d, seed: '{"a":1}'),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    final Iterable<CupertinoTextField> fields = tester
        .widgetList<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(
      fields.any((CupertinoTextField f) => f.controller?.text == '{"a":1}'),
      isTrue,
    );
  });

  testWidgets('back navigation pops the route', (WidgetTester tester) async {
    final UtilityDescriptor d = UtilityCatalog.byId('base64');
    await tester.pumpWidget(
      _hostHome(onPress: (_) => ToolDetailRoute(descriptor: d)),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsOneWidget);

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsNothing);
  });
}
