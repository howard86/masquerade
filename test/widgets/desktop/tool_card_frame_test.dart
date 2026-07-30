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
            onResizeEdge:
                (
                  dx,
                  dy, {
                  required left,
                  required right,
                  required top,
                  required bottom,
                  required measuredHeight,
                }) {},
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
            onResizeEdge:
                (
                  dx,
                  dy, {
                  required left,
                  required right,
                  required top,
                  required bottom,
                  required measuredHeight,
                }) {},
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

  group('ToolCardFrame title bar', () {
    testWidgets(
      'title exposes a Semantics-tap bridge for the double-tap-to-maximize '
      'gesture',
      (WidgetTester tester) async {
        bool maximized = false;

        await tester.pumpWidget(
          _wrap(
            ToolCardFrame(
              title: desc.name,
              slot: 1,
              focused: true,
              onFocus: () {},
              onClose: () {},
              onMinimize: () {},
              onToggleMaximize: () => maximized = true,
              onDuplicate: () {},
              onMoveDelta: (_) {},
              onMoveEnd: () {},
              onResizeEdge:
                  (
                    dx,
                    dy, {
                    required left,
                    required right,
                    required top,
                    required bottom,
                    required measuredHeight,
                  }) {},
              onResizeEnd: () {},
              child: const Text('body'),
            ),
          ),
        );

        // A real double-tap gesture has no built-in Semantics action, so
        // screen-reader users get an explicit single-activate bridge instead.
        final Finder titleSemantics = find.bySemanticsLabel(
          'Maximize ${desc.name}',
        );
        expect(titleSemantics, findsOneWidget);
        expect(
          tester.widget<Semantics>(titleSemantics).properties.onTap,
          isNotNull,
        );

        tester.widget<Semantics>(titleSemantics).properties.onTap!();
        expect(maximized, isTrue);
      },
    );
  });

  group('ToolCardFrame header semantics', () {
    testWidgets('drag/focus wrapper excludes itself from semantics so only the '
        'labelled buttons remain reachable', (WidgetTester tester) async {
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
            onDuplicate: () {},
            onMoveDelta: (_) {},
            onMoveEnd: () {},
            onResizeEdge:
                (
                  dx,
                  dy, {
                  required left,
                  required right,
                  required top,
                  required bottom,
                  required measuredHeight,
                }) {},
            onResizeEnd: () {},
            child: const Text('body'),
          ),
        ),
      );

      // The outer header GestureDetector (tap-to-focus + drag-to-move) is
      // the only one with an onPanStart handler; it wraps buttons that are
      // already individually labelled, so it shouldn't add its own
      // unlabelled tappable semantics node on top of them.
      final GestureDetector header = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((GestureDetector d) => d.onPanStart != null);
      expect(header.excludeFromSemantics, isTrue);

      // The traffic lights remain individually reachable.
      expect(find.bySemanticsLabel('Close (Esc)'), findsOneWidget);
      expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
      expect(find.bySemanticsLabel('Maximize'), findsOneWidget);
    });
  });
}
