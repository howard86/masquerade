import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/screens/desktop/desktop_sidebar.dart';
import 'package:masquerade/screens/desktop/desktop_tool_view.dart';
import 'package:masquerade/screens/history_screen.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktop = Size(1200, 900);
const Size _phone = Size(393, 852);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  bool? isWeb = true,
  MqViewMode initial = MqViewMode.desktop,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      isWebOverride: isWeb,
      viewModeController: ViewModeController(initial: initial),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DesktopShell (wide web, desktop mode)', () {
    testWidgets('renders sidebar + tool grid, no iPhone frame', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(DesktopSidebar), findsOneWidget);
      expect(find.byType(IphoneFrame), findsNothing);
      expect(find.byType(ToolGridCard), findsWidgets);
    });

    testWidgets('sidebar nav switches the content pane', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      await tester.tap(
        find.descendant(
          of: find.byType(DesktopSidebar),
          matching: find.text('History'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.byType(ToolGridCard), findsNothing);
    });

    testWidgets('tapping a tool opens it in-pane and Back returns', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      await tester.tap(find.byType(ToolGridCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopToolView), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopToolView), findsNothing);
      expect(find.byType(ToolGridCard), findsWidgets);
    });

    testWidgets('"Mobile view" toggle switches to the iPhone frame', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      await tester.tap(find.text('Mobile view'));
      await tester.pumpAndSettle();
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });
  });

  group('view-mode gating', () {
    testWidgets('mobile mode on wide web frames + offers "Desktop view"', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop, initial: MqViewMode.mobile);
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);

      await tester.tap(find.text('Desktop view'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(IphoneFrame), findsNothing);
    });

    testWidgets('narrow web → mobile UI, no shell and no toggle', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _phone);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.byType(IphoneFrame), findsNothing);
      expect(find.text('Mobile view'), findsNothing);
      expect(find.text('Desktop view'), findsNothing);
    });

    testWidgets('non-web wide viewport is unchanged (framed, no toggle)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop, isWeb: false);
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.text('Desktop view'), findsNothing);
    });
  });
}
