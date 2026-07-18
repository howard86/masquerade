import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artifact.dart';

/// Persists type-only corrections for ambiguous artifact detections.
class DetectionPreferenceController extends ChangeNotifier {
  DetectionPreferenceController({
    Map<String, ArtifactKind> preferences = const <String, ArtifactKind>{},
    SharedPreferences? prefs,
  }) : _preferences = Map<String, ArtifactKind>.of(preferences),
       _prefs = prefs;

  static const String storageKey = 'mb.detection.type_preferences';
  static const String _tenDigitInteger = 'ten_digit_integer';

  final Map<String, ArtifactKind> _preferences;
  SharedPreferences? _prefs;

  bool get hasPreferences => _preferences.isNotEmpty;

  bool canPrefer(List<DetectionMatch<Object?>> matches) =>
      _key(matches) != null;

  static Future<DetectionPreferenceController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, ArtifactKind> preferences = <String, ArtifactKind>{};
    for (final String entry
        in prefs.getStringList(storageKey) ?? const <String>[]) {
      final int separator = entry.lastIndexOf('=');
      if (separator <= 0) continue;
      final String key = entry.substring(0, separator);
      final String value = entry.substring(separator + 1);
      final ArtifactKind? kind = _kind(value);
      if (kind != null &&
          key == _tenDigitInteger &&
          (kind == ArtifactKind.timestamp || kind == ArtifactKind.number)) {
        preferences[key] = kind;
      }
    }
    return DetectionPreferenceController(
      preferences: preferences,
      prefs: prefs,
    );
  }

  List<DetectionMatch<Object?>> rank(List<DetectionMatch<Object?>> matches) {
    final String? key = _key(matches);
    final ArtifactKind? preferred = key == null ? null : _preferences[key];
    if (preferred == null) return matches;
    return List<DetectionMatch<Object?>>.unmodifiable(<DetectionMatch<Object?>>[
      ...matches.where((match) => match.artifact.kind == preferred),
      ...matches.where((match) => match.artifact.kind != preferred),
    ]);
  }

  Future<void> prefer(
    List<DetectionMatch<Object?>> matches,
    ArtifactKind preferred,
  ) async {
    final String? key = _key(matches);
    if (key == null || !matches.any((m) => m.artifact.kind == preferred)) {
      return;
    }
    if (_preferences[key] == preferred) return;
    _preferences[key] = preferred;
    notifyListeners();
    await _persist();
  }

  Future<void> reset() async {
    final bool changed = _preferences.isNotEmpty;
    _preferences.clear();
    if (changed) notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.remove(storageKey);
  }

  Future<void> _persist() async {
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final List<String> entries =
        _preferences.entries
            .map((entry) => '${entry.key}=${entry.value.name}')
            .toList()
          ..sort();
    await prefs.setStringList(storageKey, entries);
  }

  static String? _key(List<DetectionMatch<Object?>> matches) {
    final Set<ArtifactKind> kinds = matches
        .map((match) => match.artifact.kind)
        .toSet();
    if (kinds.length == 2 &&
        kinds.contains(ArtifactKind.timestamp) &&
        kinds.contains(ArtifactKind.number) &&
        RegExp(
          r'^-?\d{10}$',
        ).hasMatch(matches.first.artifact.rawValue.trim())) {
      return _tenDigitInteger;
    }
    return null;
  }

  static ArtifactKind? _kind(String name) {
    for (final ArtifactKind kind in ArtifactKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

class DetectionPreferenceScope
    extends InheritedNotifier<DetectionPreferenceController> {
  const DetectionPreferenceScope({
    super.key,
    required DetectionPreferenceController controller,
    required super.child,
  }) : super(notifier: controller);

  static DetectionPreferenceController of(BuildContext context) {
    final DetectionPreferenceController? controller = maybeOf(context);
    assert(controller != null, 'DetectionPreferenceScope not found.');
    return controller!;
  }

  static DetectionPreferenceController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DetectionPreferenceScope>()
      ?.notifier;
}
