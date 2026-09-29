import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Finder _dotGrid = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_DotGridPainter',
);

Future<Uint8List> _dotGridPixels(WidgetTester tester, double dpr) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject(_dotGrid).parent! as RenderRepaintBoundary;
  final Uint8List? bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: dpr);
    final ByteData? data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final double dpr in <double>[1, 2]) {
    testWidgets('dot grid paint is stable across pan and resize at DPR$dpr', (
      WidgetTester tester,
    ) async {
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

      // Snapshot only the dot grid's own boundary and compare in-run, so the
      // check is independent of platform text/gradient rasterization.
      final Uint8List base = await _dotGridPixels(tester, dpr);
      expect(base.any((int byte) => byte != 0), isTrue);

      final GestureDetector detector = tester.widget(
        find
            .ancestor(of: _dotGrid, matching: find.byType(GestureDetector))
            .first,
      );
      detector.onPanUpdate!(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(7, 11),
        ),
      );
      await tester.pump();
      expect(await _dotGridPixels(tester, dpr), isNot(equals(base)));

      detector.onPanUpdate!(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(-7, -11),
        ),
      );
      await tester.pump();
      expect(await _dotGridPixels(tester, dpr), equals(base));

      await tester.binding.setSurfaceSize(const Size(1190, 900));
      await tester.pump();
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pump();
      expect(await _dotGridPixels(tester, dpr), equals(base));
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
