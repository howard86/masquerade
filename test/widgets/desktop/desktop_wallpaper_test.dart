import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/desktop/desktop_wallpaper.dart';

Widget _wallpaper(MqWallpaperType type, Brightness brightness) {
  return MqTheme(
    tokens: MqTokens(
      colors: brightness == Brightness.dark
          ? MqColors.dark()
          : MqColors.light(),
      brightness: brightness,
    ),
    child: WallpaperScope(
      controller: WallpaperController(initial: type),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: DesktopWallpaper(),
      ),
    ),
  );
}

Color? _baseColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(DesktopWallpaper),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  for (final MqWallpaperType type in MqWallpaperType.values) {
    testWidgets('$type paints on its own layer without a backdrop blur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wallpaper(type, Brightness.light));

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

  testWidgets('auto paints parchment under a light theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wallpaper(MqWallpaperType.auto, Brightness.light));
    expect(_baseColor(tester), const Color(0xFFFBF9F6));
  });

  testWidgets('auto paints aurora under a dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wallpaper(MqWallpaperType.auto, Brightness.dark));
    expect(_baseColor(tester), const Color(0xFF100E0C));
  });
}
