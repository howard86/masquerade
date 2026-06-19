import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_dock.dart';

Widget _wrap(CanvasController controller) {
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: Center(
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? _) =>
              DesktopDock(controller: controller),
        ),
      ),
    ),
  );
}

void main() {
  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor timestamp = UtilityCatalog.byId('timestamp');

  group('DesktopDock', () {
    testWidgets('hidden when no windows are open', (WidgetTester tester) async {
      final CanvasController c = CanvasController();
      await tester.pumpWidget(_wrap(c));

      expect(find.byType(SizedBox), findsWidgets);
      // Dock container should not be present.
      expect(find.byType(DesktopDock), findsOneWidget);
      // But it renders SizedBox.shrink — no icon tiles.
      expect(find.byIcon(json.icon), findsNothing);
    });

    testWidgets('shows one tile per open window', (WidgetTester tester) async {
      final CanvasController c = CanvasController();
      c.openTool(json);
      c.openTool(timestamp);
      await tester.pumpWidget(_wrap(c));

      expect(find.byIcon(json.icon), findsOneWidget);
      expect(find.byIcon(timestamp.icon), findsOneWidget);
    });

    testWidgets('minimized windows shown (dimmed)', (
      WidgetTester tester,
    ) async {
      final CanvasController c = CanvasController();
      final int a = c.openTool(json);
      c.minimize(a);
      await tester.pumpWidget(_wrap(c));

      // The icon is still visible in the dock.
      expect(find.byIcon(json.icon), findsOneWidget);
      // It's wrapped in an Opacity widget with 0.4.
      final Opacity opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byIcon(json.icon),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('exposes Semantics labels with title and minimized state', (
      WidgetTester tester,
    ) async {
      final CanvasController c = CanvasController();
      final int a = c.openTool(json);
      c.openTool(timestamp);
      c.minimize(a);
      await tester.pumpWidget(_wrap(c));

      // Open tile announces its title as a button-labelled window.
      expect(find.bySemanticsLabel('${timestamp.name} window'), findsOneWidget);
      // Minimized tile announces its title plus the minimized state.
      expect(
        find.bySemanticsLabel('${json.name} window, minimized'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('minimized')), findsOneWidget);
    });

    testWidgets('click focuses/restores a minimized window', (
      WidgetTester tester,
    ) async {
      final CanvasController c = CanvasController();
      final int a = c.openTool(json);
      c.openTool(timestamp);
      c.minimize(a);
      await tester.pumpWidget(_wrap(c));

      await tester.tap(find.byIcon(json.icon));
      await tester.pump();

      expect(c.cards[0].minimized, isFalse);
      expect(c.focusedId, a);
    });
  });
}
