import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_canvas.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final double dpr in <double>[1, 2]) {
    testWidgets('dot grid matches at DPR$dpr', (WidgetTester tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(1200 * dpr, 900 * dpr);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MyApp(
          desktopShellOverride: true,
          viewModeController: ViewModeController(initial: MqViewMode.desktop),
          skipSplash: true,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DesktopCanvas),
        matchesGoldenFile('goldens/dot_grid_${dpr.toInt()}x.png'),
      );
      final Finder dotGrid = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_DotGridPainter',
      );
      final GestureDetector detector = tester.widget(
        find
            .ancestor(of: dotGrid, matching: find.byType(GestureDetector))
            .first,
      );
      detector.onPanUpdate!(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(7, 11),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(DesktopCanvas),
        matchesGoldenFile('goldens/dot_grid_pan_${dpr.toInt()}x.png'),
      );
      detector.onPanUpdate!(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(-7, -11),
        ),
      );
      await tester.pump();
      await tester.binding.setSurfaceSize(const Size(1190, 900));
      await tester.pump();
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pump();
      await expectLater(
        find.byType(DesktopCanvas),
        matchesGoldenFile('goldens/dot_grid_${dpr.toInt()}x.png'),
      );
    });
  }

  testWidgets('boundary isolates paint without intercepting canvas behavior', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MyApp(
        desktopShellOverride: true,
        viewModeController: ViewModeController(initial: MqViewMode.desktop),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    final Finder dotGrid = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_DotGridPainter',
    );
    final RenderObject gridRenderObject = tester.renderObject(dotGrid);
    expect(gridRenderObject.parent, isA<RenderRepaintBoundary>());
    final Finder detectorFinder = find
        .ancestor(of: dotGrid, matching: find.byType(GestureDetector))
        .first;
    final GestureDetector detector = tester.widget(detectorFinder);
    expect(detector.behavior, HitTestBehavior.opaque);
    final Finder dropTarget = find.ancestor(
      of: dotGrid,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget.runtimeType.toString().startsWith('DragTarget<'),
      ),
    );
    expect(dropTarget, findsOneWidget);

    detector.onSecondaryTapDown!(
      TapDownDetails(globalPosition: const Offset(20, 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose Wallpaper...'), findsOneWidget);
  });
}
