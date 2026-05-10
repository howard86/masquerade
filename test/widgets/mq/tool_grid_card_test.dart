import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';

Widget _harness({
  required UtilityDescriptor descriptor,
  required bool matched,
  HistoryEntry? lastEntry,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: CupertinoPageScaffold(
        child: SizedBox(
          width: 200,
          height: 120,
          child: Center(
            child: ToolGridCard(
              descriptor: descriptor,
              matched: matched,
              lastEntry: lastEntry,
              onTap: onTap ?? () {},
              onLongPress: onLongPress,
            ),
          ),
        ),
      ),
    ),
  );
}

HistoryEntry _entry(String utilityId, String input, {bool sensitive = false}) =>
    HistoryEntry(
      utilityId: utilityId,
      input: input,
      output: 'out',
      timestamp: DateTime(2026, 5, 10),
      sensitive: sensitive,
    );

void main() {
  final UtilityDescriptor sample = UtilityCatalog.byId('base64');

  testWidgets('idle renders icon, name, description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(descriptor: sample, matched: false));
    expect(find.text(sample.name), findsOneWidget);
    expect(find.text(sample.description), findsOneWidget);
  });

  testWidgets('with lastEntry renders mono preview, hides description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        descriptor: sample,
        matched: false,
        lastEntry: _entry('base64', 'hello-world'),
      ),
    );
    expect(find.text('hello-world'), findsOneWidget);
    expect(find.text(sample.description), findsNothing);
  });

  testWidgets('preview truncates over 24 chars', (WidgetTester tester) async {
    const String long = 'abcdefghijklmnopqrstuvwxyz0123456789';
    await tester.pumpWidget(
      _harness(
        descriptor: sample,
        matched: false,
        lastEntry: _entry('base64', long),
      ),
    );
    expect(find.text('${long.substring(0, 24)}…'), findsOneWidget);
  });

  testWidgets('sensitive entry masks preview with bullets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        descriptor: sample,
        matched: false,
        lastEntry: _entry('base64', 'super-secret', sensitive: true),
      ),
    );
    expect(find.text('super-secret'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets('matched=true paints accent border', (WidgetTester tester) async {
    final MqColors light = MqColors.light();
    await tester.pumpWidget(_harness(descriptor: sample, matched: true));
    final Finder containers = find.descendant(
      of: find.byType(ToolGridCard),
      matching: find.byType(Container),
    );
    final Container container = tester.widget<Container>(containers.first);
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.border!.top.color, light.accent);
    expect(deco.border!.top.width, 1.0);
  });

  testWidgets('matched=false paints hairline border', (
    WidgetTester tester,
  ) async {
    final MqColors light = MqColors.light();
    await tester.pumpWidget(_harness(descriptor: sample, matched: false));
    final Finder containers = find.descendant(
      of: find.byType(ToolGridCard),
      matching: find.byType(Container),
    );
    final Container container = tester.widget<Container>(containers.first);
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.border!.top.color, light.border);
    expect(deco.border!.top.width, 0.5);
  });

  testWidgets('tap fires onTap', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _harness(descriptor: sample, matched: false, onTap: () => taps++),
    );
    await tester.tap(find.byType(ToolGridCard));
    expect(taps, 1);
  });

  testWidgets('long-press fires onLongPress', (WidgetTester tester) async {
    int presses = 0;
    await tester.pumpWidget(
      _harness(
        descriptor: sample,
        matched: false,
        onLongPress: () => presses++,
      ),
    );
    await tester.longPress(find.byType(ToolGridCard));
    expect(presses, 1);
  });
}
