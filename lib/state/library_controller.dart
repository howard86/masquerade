import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted Library preferences.
class LibraryController extends ChangeNotifier {
  LibraryController({
    Iterable<String> favorites = const <String>[],
    SharedPreferences? prefs,
  }) : _favorites = favorites.toSet(),
       _prefs = prefs;

  static const String _favoritesKey = 'mb.library.favorite_ids';

  final Set<String> _favorites;
  SharedPreferences? _prefs;

  Set<String> get favorites => Set<String>.unmodifiable(_favorites);

  bool isFavorite(String toolId) => _favorites.contains(toolId);

  static Future<LibraryController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return LibraryController(
      favorites: prefs.getStringList(_favoritesKey) ?? const <String>[],
      prefs: prefs,
    );
  }

  Future<void> toggleFavorite(String toolId) async {
    if (!_favorites.remove(toolId)) _favorites.add(toolId);
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setStringList(_favoritesKey, _favorites.toList());
  }
}

class LibraryScope extends InheritedNotifier<LibraryController> {
  const LibraryScope({
    super.key,
    required LibraryController controller,
    required super.child,
  }) : super(notifier: controller);

  static LibraryController of(BuildContext context) {
    final LibraryScope? scope = context
        .dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'LibraryScope not found.');
    return scope!.notifier!;
  }
}
