import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which layout the user wants on a wide web window. Only meaningful when the
/// desktop shell is available (web + viewport ≥ [MqLayout.desktopBreakpoint]);
/// elsewhere it is ignored and the mobile UI always renders.
enum MqViewMode { desktop, mobile }

/// Persisted desktop↔mobile layout preference for web. Mirrors the
/// [DensityController] / [ThemeController] pattern. Defaults to [desktop] so a
/// brand-new visitor on a wide browser lands in the desktop layout.
class ViewModeController extends ChangeNotifier {
  ViewModeController({
    MqViewMode initial = MqViewMode.desktop,
    SharedPreferences? prefs,
  }) : _mode = initial,
       _prefs = prefs;

  static const String _prefsKey = 'mb.view.mode';

  MqViewMode _mode;
  SharedPreferences? _prefs;

  MqViewMode get mode => _mode;

  /// Hydrate from disk. Safe to call once at startup.
  static Future<ViewModeController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    final MqViewMode mode = _decode(raw) ?? MqViewMode.desktop;
    return ViewModeController(initial: mode, prefs: prefs);
  }

  Future<void> setMode(MqViewMode next) async {
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsKey, next.name);
  }

  Future<void> toggle() => setMode(
    _mode == MqViewMode.desktop ? MqViewMode.mobile : MqViewMode.desktop,
  );

  static MqViewMode? _decode(String? raw) {
    if (raw == null) return null;
    for (final MqViewMode m in MqViewMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

/// Provides a [ViewModeController] to descendants. Listeners rebuild on change.
class ViewModeScope extends InheritedNotifier<ViewModeController> {
  const ViewModeScope({
    super.key,
    required ViewModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ViewModeController of(BuildContext context) {
    final ViewModeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ViewModeScope>();
    assert(
      scope != null,
      'ViewModeScope not found. Wrap your app in ViewModeScope.',
    );
    return scope!.notifier!;
  }
}
