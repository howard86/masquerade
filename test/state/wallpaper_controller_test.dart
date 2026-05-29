import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('WallpaperController', () {
    test('default wallpaper is auroraEspresso', () {
      expect(WallpaperController().type, MqWallpaperType.auroraEspresso);
    });

    test('setType notifies listeners and persists', () async {
      int notifyCount = 0;
      final WallpaperController c = WallpaperController();
      c.addListener(() => notifyCount++);

      await c.setType(MqWallpaperType.cyberGlass);
      expect(notifyCount, 1);
      expect(c.type, MqWallpaperType.cyberGlass);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mb.wallpaper.type'), 'cyberGlass');
    });

    test('setType is a no-op when type is unchanged', () async {
      int notifyCount = 0;
      final WallpaperController c = WallpaperController();
      c.addListener(() => notifyCount++);
      await c.setType(MqWallpaperType.auroraEspresso);
      expect(notifyCount, 0);
    });

    test('load() hydrates persisted wallpaper', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.wallpaper.type': 'slateSolid',
      });
      final WallpaperController c = await WallpaperController.load();
      expect(c.type, MqWallpaperType.slateSolid);
    });

    test(
      'load() falls back to auroraEspresso on missing/invalid values',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'mb.wallpaper.type': 'bogus',
        });
        final WallpaperController c = await WallpaperController.load();
        expect(c.type, MqWallpaperType.auroraEspresso);
      },
    );
  });
}
