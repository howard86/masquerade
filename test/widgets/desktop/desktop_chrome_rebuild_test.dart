import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_dock.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('desktop chrome rebuilds only for state it displays', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        desktopShellOverride: true,
        viewModeController: ViewModeController(initial: MqViewMode.desktop),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    final CanvasController canvas = tester
        .widget<DesktopMenubar>(find.byType(DesktopMenubar))
        .controller;
    final int json = canvas.openTool(UtilityCatalog.byId('json'));
    final int uuid = canvas.openTool(UtilityCatalog.byId('uuid'));
    await tester.pump();

    final Element menubarProbe = find.text('Window').evaluate().single;
    final Element dockProbe = find.byType(DesktopDock).evaluate().single;
    Widget menubarWidget = menubarProbe.widget;
    Widget dockWidget = dockProbe.widget;

    canvas.moveBy(json, 20, 10);
    await tester.pump();
    expect(menubarProbe.widget, same(menubarWidget));
    expect(dockProbe.widget, same(dockWidget));

    canvas.resize(json, 700);
    await tester.pump();
    expect(menubarProbe.widget, same(menubarWidget));
    expect(dockProbe.widget, same(dockWidget));

    canvas.focus(json);
    await tester.pump();
    expect(menubarProbe.widget, same(menubarWidget));
    expect(dockProbe.widget, isNot(same(dockWidget)));
    dockWidget = dockProbe.widget;

    canvas.minimize(json);
    await tester.pump();
    expect(menubarProbe.widget, same(menubarWidget));
    expect(dockProbe.widget, isNot(same(dockWidget)));
    expect(
      find.bySemanticsLabel('JSON / YAML / TOML window, minimized'),
      findsOneWidget,
    );
    dockWidget = dockProbe.widget;

    canvas.restoreWindow(json);
    await tester.pump();
    expect(menubarProbe.widget, same(menubarWidget));
    expect(dockProbe.widget, isNot(same(dockWidget)));
    dockWidget = dockProbe.widget;

    canvas.duplicate(uuid);
    await tester.pump();
    expect(menubarProbe.widget, isNot(same(menubarWidget)));
    expect(dockProbe.widget, isNot(same(dockWidget)));
    menubarWidget = menubarProbe.widget;
    dockWidget = dockProbe.widget;

    canvas.close(uuid);
    await tester.pump();
    expect(menubarProbe.widget, isNot(same(menubarWidget)));
    expect(dockProbe.widget, isNot(same(dockWidget)));

    await tester.tap(find.text('Window'));
    await tester.pump();
    expect(find.text('JSON / YAML / TOML'), findsWidgets);
    expect(find.text('UUID'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
