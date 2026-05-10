import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/mq_density.dart';

/// Persisted density mode override. Mirrors [ThemeController] pattern.
class DensityController extends ChangeNotifier {
  DensityController({
    MqDensityMode initial = MqDensityMode.comfortable,
    SharedPreferences? prefs,
  }) : _mode = initial,
       _prefs = prefs;

  static const String _prefsKey = 'mb.density.mode';

  MqDensityMode _mode;
  SharedPreferences? _prefs;

  MqDensityMode get mode => _mode;

  MqDensity get density => _mode == MqDensityMode.compact
      ? MqDensity.compact()
      : MqDensity.comfortable();

  /// Hydrate from disk. Safe to call once at startup.
  static Future<DensityController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    final MqDensityMode mode = _decode(raw) ?? MqDensityMode.comfortable;
    return DensityController(initial: mode, prefs: prefs);
  }

  Future<void> setMode(MqDensityMode next) async {
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsKey, next.name);
  }

  static MqDensityMode? _decode(String? raw) {
    if (raw == null) return null;
    for (final MqDensityMode m in MqDensityMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

/// Provides a [DensityController] to descendants. Listeners rebuild on change.
class DensityScope extends InheritedNotifier<DensityController> {
  const DensityScope({
    super.key,
    required DensityController controller,
    required super.child,
  }) : super(notifier: controller);

  static DensityController of(BuildContext context) {
    final DensityScope? scope = context
        .dependOnInheritedWidgetOfExactType<DensityScope>();
    assert(
      scope != null,
      'DensityScope not found. Wrap your app in DensityScope.',
    );
    return scope!.notifier!;
  }
}
