import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:masquerade/widgets/desktop/desktop_wallpaper.dart';

void main() {
  for (final MqWallpaperType type in MqWallpaperType.values) {
    testWidgets('$type paints on its own layer without a backdrop blur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        WallpaperScope(
          controller: WallpaperController(initial: type),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: DesktopWallpaper(),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DesktopWallpaper),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  }
}
