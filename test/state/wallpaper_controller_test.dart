import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('WallpaperController', () {
    test('default wallpaper is auto', () {
      expect(WallpaperController().type, MqWallpaperType.auto);
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
      await c.setType(MqWallpaperType.auto);
      expect(notifyCount, 0);
    });

    test('load() hydrates persisted wallpaper', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.wallpaper.type': 'slateSolid',
      });
      final WallpaperController c = await WallpaperController.load();
      expect(c.type, MqWallpaperType.slateSolid);
    });

    test('load() falls back to auto on missing/invalid values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.wallpaper.type': 'bogus',
      });
      final WallpaperController c = await WallpaperController.load();
      expect(c.type, MqWallpaperType.auto);
    });
  });

  group('MqWallpaperType resolve/brightness', () {
    const Map<MqWallpaperType, MqWallpaperType> lightResolved =
        <MqWallpaperType, MqWallpaperType>{
          MqWallpaperType.auto: MqWallpaperType.parchmentMinimalist,
          MqWallpaperType.auroraEspresso: MqWallpaperType.auroraEspresso,
          MqWallpaperType.parchmentMinimalist:
              MqWallpaperType.parchmentMinimalist,
          MqWallpaperType.cyberGlass: MqWallpaperType.cyberGlass,
          MqWallpaperType.slateSolid: MqWallpaperType.slateSolid,
        };

    for (final MqWallpaperType t in MqWallpaperType.values) {
      test('$t resolves and reports brightness', () {
        expect(t.resolve(Brightness.light), lightResolved[t]);
        expect(
          t.resolve(Brightness.dark),
          t == MqWallpaperType.auto ? MqWallpaperType.auroraEspresso : t,
        );
        final bool parchmentLight =
            t == MqWallpaperType.parchmentMinimalist ||
            t == MqWallpaperType.auto;
        expect(
          t.brightness(Brightness.light),
          parchmentLight ? Brightness.light : Brightness.dark,
        );
        expect(
          t.brightness(Brightness.dark),
          t == MqWallpaperType.parchmentMinimalist
              ? Brightness.light
              : Brightness.dark,
        );
      });
    }
  });
}
