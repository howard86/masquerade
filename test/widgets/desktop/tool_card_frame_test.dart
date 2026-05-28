import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';

Widget _wrap(Widget child) {
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: Center(child: SizedBox(width: 400, child: child)),
    ),
  );
}

void main() {
  final UtilityDescriptor desc = UtilityCatalog.byId('json');

  group('ToolCardFrame traffic lights', () {
    testWidgets('close, minimize, maximize buttons fire callbacks', (
      WidgetTester tester,
    ) async {
      bool closed = false;
      bool minimized = false;
      bool maximized = false;

      await tester.pumpWidget(
        _wrap(
          ToolCardFrame(
            title: desc.name,
            slot: 1,
            focused: true,
            onFocus: () {},
            onClose: () => closed = true,
            onMinimize: () => minimized = true,
            onToggleMaximize: () => maximized = true,
            onDuplicate: () {},
            onMoveDelta: (_) {},
            onMoveEnd: () {},
            onResizeEdge: (dx, dy, {required left, required right, required top, required bottom, required measuredHeight}) {},
            onResizeEnd: () {},
            child: const Text('body'),
          ),
        ),
      );

      // Traffic lights are the three Container circles with BoxShape.circle.
      // Find them by semantics label.
      await tester.tap(find.bySemanticsLabel('Close (Esc)'));
      expect(closed, isTrue);

      await tester.tap(find.bySemanticsLabel('Minimize'));
      expect(minimized, isTrue);

      await tester.tap(find.bySemanticsLabel('Maximize'));
      expect(maximized, isTrue);
    });

    testWidgets('link and duplicate buttons still present', (
      WidgetTester tester,
    ) async {
      bool linked = false;
      bool duplicated = false;

      await tester.pumpWidget(
        _wrap(
          ToolCardFrame(
            title: desc.name,
            slot: 1,
            focused: true,
            onFocus: () {},
            onClose: () {},
            onMinimize: () {},
            onToggleMaximize: () {},
            onDuplicate: () => duplicated = true,
            onMoveDelta: (_) {},
            onMoveEnd: () {},
            onResizeEdge: (dx, dy, {required left, required right, required top, required bottom, required measuredHeight}) {},
            onResizeEnd: () {},
            onLink: () => linked = true,
            child: const Text('body'),
          ),
        ),
      );

      await tester.tap(find.byIcon(MqIcons.link));
      expect(linked, isTrue);

      await tester.tap(find.byIcon(MqIcons.copy));
      expect(duplicated, isTrue);
    });
  });
}
