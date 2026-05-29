import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MqWallpaperType {
  auroraEspresso,
  parchmentMinimalist,
  cyberGlass,
  slateSolid,
}

extension MqWallpaperTypeExtension on MqWallpaperType {
  String get displayName => switch (this) {
    MqWallpaperType.auroraEspresso => 'Aurora Espresso',
    MqWallpaperType.parchmentMinimalist => 'Parchment Minimalist',
    MqWallpaperType.cyberGlass => 'Cyber Glass',
    MqWallpaperType.slateSolid => 'Slate Solid',
  };
}

/// Persisted wallpaper selection. Mirrors ThemeController and DensityController.
class WallpaperController extends ChangeNotifier {
  WallpaperController({
    MqWallpaperType initial = MqWallpaperType.auroraEspresso,
    SharedPreferences? prefs,
  }) : _type = initial,
       _prefs = prefs;

  static const String _prefsKey = 'mb.wallpaper.type';

  MqWallpaperType _type;
  SharedPreferences? _prefs;

  MqWallpaperType get type => _type;

  /// Hydrate from disk. Safe to call once at startup.
  static Future<WallpaperController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    final MqWallpaperType type = _decode(raw) ?? MqWallpaperType.auroraEspresso;
    return WallpaperController(initial: type, prefs: prefs);
  }

  Future<void> setType(MqWallpaperType next) async {
    if (next == _type) return;
    _type = next;
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsKey, next.name);
  }

  static MqWallpaperType? _decode(String? raw) {
    if (raw == null) return null;
    for (final MqWallpaperType t in MqWallpaperType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }
}

/// Provides a [WallpaperController] to descendants. Listeners rebuild on change.
class WallpaperScope extends InheritedNotifier<WallpaperController> {
  const WallpaperScope({
    super.key,
    required WallpaperController controller,
    required super.child,
  }) : super(notifier: controller);

  static WallpaperController of(BuildContext context) {
    final WallpaperScope? scope = context
        .dependOnInheritedWidgetOfExactType<WallpaperScope>();
    assert(
      scope != null,
      'WallpaperScope not found. Wrap your app in WallpaperScope.',
    );
    return scope!.notifier!;
  }
}
