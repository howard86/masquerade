import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted set of starred utility IDs.
class FavoritesController extends ChangeNotifier {
  FavoritesController({Set<String>? initial, SharedPreferences? prefs})
    : _ids = initial ?? <String>{},
      _prefs = prefs;

  static const String _prefsKey = 'mb.favorites.ids';

  final Set<String> _ids;
  SharedPreferences? _prefs;

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool isFavorite(String id) => _ids.contains(id);

  static Future<FavoritesController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    return FavoritesController(initial: raw.toSet(), prefs: prefs);
  }

  Future<void> toggle(String id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setStringList(_prefsKey, _ids.toList()..sort());
  }
}

class FavoritesScope extends InheritedNotifier<FavoritesController> {
  const FavoritesScope({
    super.key,
    required FavoritesController controller,
    required super.child,
  }) : super(notifier: controller);

  static FavoritesController of(BuildContext context) {
    final FavoritesScope? scope = context
        .dependOnInheritedWidgetOfExactType<FavoritesScope>();
    assert(scope != null, 'FavoritesScope not found.');
    return scope!.notifier!;
  }
}
