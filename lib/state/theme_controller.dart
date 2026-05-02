import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme override: follow system, force light, or force dark.
enum MqThemeMode { system, light, dark }

/// Persisted theme mode override.
class ThemeController extends ChangeNotifier {
  ThemeController({
    MqThemeMode initial = MqThemeMode.system,
    SharedPreferences? prefs,
  }) : _mode = initial,
       _prefs = prefs;

  static const String _prefsKey = 'mb.theme.mode';

  MqThemeMode _mode;
  SharedPreferences? _prefs;

  MqThemeMode get mode => _mode;

  /// Hydrate from disk. Safe to call once at startup.
  static Future<ThemeController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    final MqThemeMode mode = _decode(raw) ?? MqThemeMode.system;
    return ThemeController(initial: mode, prefs: prefs);
  }

  Future<void> setMode(MqThemeMode next) async {
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsKey, _encode(next));
  }

  static String _encode(MqThemeMode m) => switch (m) {
    MqThemeMode.system => 'system',
    MqThemeMode.light => 'light',
    MqThemeMode.dark => 'dark',
  };

  static MqThemeMode? _decode(String? raw) => switch (raw) {
    'system' => MqThemeMode.system,
    'light' => MqThemeMode.light,
    'dark' => MqThemeMode.dark,
    _ => null,
  };
}

/// Provides a [ThemeController] to descendants. Listeners rebuild on mode change.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final ThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found. Wrap your app in ThemeScope.');
    return scope!.notifier!;
  }
}
