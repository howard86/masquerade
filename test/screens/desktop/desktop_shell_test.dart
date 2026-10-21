import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/state/canvas_controller.dart';
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
  bool? desktopShell = true,
  MqViewMode initial = MqViewMode.desktop,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: desktopShell,
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

    testWidgets('opening a tool focuses its first text input', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      await tester.tap(find.text(UtilityCatalog.all.first.name));
      await tester.pumpAndSettle();

      final CupertinoTextField input = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField).first,
      );
      expect(input.focusNode?.hasFocus, isTrue);
    });

    testWidgets('empty desktop shows the shortcut hint only without cards', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      const String hint = '⌘K open a tool · ⌘V paste anything';
      expect(find.text(hint), findsOneWidget);

      await tester.tap(find.text(UtilityCatalog.all.first.name));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);

      await tester.tap(find.bySemanticsLabel('Close (Esc)'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('unrecognized paste shows a transient notice', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object>{'text': 'plain unrecognized words'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(tester, size: _desktop);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste & Detect  ⌘V'));
      await tester.pumpAndSettle();

      expect(find.text('No tool recognized this text'), findsOneWidget);
      expect(
        find.bySemanticsLabel('No tool recognized this text'),
        findsOneWidget,
      );
      expect(find.byType(ToolCardFrame), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.bySemanticsLabel('No tool recognized this text'),
        findsNothing,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey<String>('unrecognized-paste-notice')),
            )
            .opacity,
        0,
      );
      semantics.dispose();
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
          desktopShellOverride: true,
          viewModeController: ViewModeController(initial: MqViewMode.desktop),
          skipSplash: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);
    });

    testWidgets('startup-restored tool does not request body focus', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        CanvasController.currentKey: jsonEncode(<String, Object>{
          'nextId': 2,
          'nextZ': 2,
          'focused': 1,
          'cards': <Map<String, Object>>[
            <String, Object>{
              'id': 1,
              'tool': 'json',
              'x': 32,
              'y': 24,
              'w': 520,
              'z': 1,
            },
          ],
          'groups': <Object>[],
        }),
      });
      await _pump(tester, size: _desktop);

      final CupertinoTextField input = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField).first,
      );
      expect(input.focusNode?.hasFocus, isFalse);
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

    testWidgets('app pause flushes a debounced canvas snapshot', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop);
      final CanvasController canvas = tester
          .widget<DesktopMenubar>(find.byType(DesktopMenubar))
          .controller;
      final int a = canvas.openTool(UtilityCatalog.byId('json'));
      canvas.openTool(UtilityCatalog.byId('uuid'));
      await tester.pump();
      canvas.focus(a);
      expect(canvas.hasPendingPersist, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(canvas.hasPendingPersist, isFalse);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> saved =
          jsonDecode(prefs.getString(CanvasController.currentKey)!)
              as Map<String, dynamic>;
      expect(saved['focused'], a);
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    });
  });

  group('view-mode gating', () {
    testWidgets('native macOS opens the desktop OS without an override', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _pump(tester, size: _desktop, desktopShell: null);

        expect(find.byType(DesktopShell), findsOneWidget);
        expect(find.byType(IphoneFrame), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

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

    testWidgets('unsupported wide viewport stays framed with no toggle', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: _desktop, desktopShell: false);
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
      expect(find.byKey(ViewModeToggleButton.compactKey), findsNothing);
    });
  });
}
