import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
import 'package:masquerade/widgets/mq/view_mode_toggle_button.dart';
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
    testWidgets('renders menubar + icon grid, no sidebar, no iPhone frame', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(DesktopMenubar), findsOneWidget);
      expect(find.byType(IphoneFrame), findsNothing);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
    });

    testWidgets('shell fills the viewport (not height-capped)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: const Size(1200, 1100));
      final Size shell = tester.getSize(find.byType(DesktopShell));
      // Full-bleed: shell fills the entire viewport height.
      expect(shell.height, 1100);
    });

    testWidgets('tapping a tool opens a canvas card; closing it returns', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      final String firstName = UtilityCatalog.all.first.name;
      await tester.tap(find.text(firstName));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);
      // Icon grid stays visible (always present).
      expect(find.byType(DesktopIconGrid), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close (Esc)'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsNothing);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
    });

    testWidgets('canvas auto-restores open cards after a reload', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      final String firstName = UtilityCatalog.all.first.name;
      await tester.tap(find.text(firstName));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);

      await tester.pumpWidget(
        MyApp(
          isWebOverride: true,
          viewModeController: ViewModeController(initial: MqViewMode.desktop),
          skipSplash: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);
    });

    testWidgets('menubar "Mobile view" switches to the iPhone frame', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      // Open the ⏻ Masquerade menu.
      await tester.tap(find.text('⏻ Masquerade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile view'));
      await tester.pumpAndSettle();
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });

    testWidgets('menubar File → "Open Layout…" opens the layouts sheet', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Layout…'));
      await tester.pumpAndSettle();
      expect(find.text('Save current canvas…'), findsOneWidget);
    });
  });

  group('view-mode gating', () {
    testWidgets('mobile mode on wide web frames + offers "Desktop view"', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop, initial: MqViewMode.mobile);
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.byKey(ViewModeToggleButton.compactKey), findsOneWidget);

      await tester.tap(find.byKey(ViewModeToggleButton.compactKey));
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
      expect(find.byKey(ViewModeToggleButton.compactKey), findsNothing);
    });

    testWidgets('non-web wide viewport is unchanged (framed, no toggle)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop, isWeb: false);
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.byKey(ViewModeToggleButton.compactKey), findsNothing);
    });
  });
}
