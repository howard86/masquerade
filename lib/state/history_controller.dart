import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One captured utility action.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.utilityId,
    required this.input,
    required this.output,
    required this.timestamp,
    this.sensitive = false,
  });

  final String utilityId;
  final String input;
  final String output;
  final DateTime timestamp;
  final bool sensitive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'utilityId': utilityId,
    'input': input,
    'output': output,
    'ts': timestamp.millisecondsSinceEpoch,
    'sensitive': sensitive,
  };

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
    utilityId: json['utilityId'] as String,
    input: json['input'] as String,
    output: json['output'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    sensitive: json['sensitive'] as bool? ?? false,
  );
}

/// On-device history of utility usage. 7-day retention by default.
class HistoryController extends ChangeNotifier {
  HistoryController({
    Duration retention = const Duration(days: 7),
    int maxEntries = 200,
    SharedPreferences? prefs,
  }) : _retention = retention,
       _maxEntries = maxEntries,
       _prefs = prefs;

  static const String _prefsKey = 'mb.history.entries';
  static const String _retentionKey = 'mb.history.retention.days';

  Duration _retention;
  final int _maxEntries;
  SharedPreferences? _prefs;
  List<HistoryEntry> _entries = <HistoryEntry>[];

  List<HistoryEntry> get entries => List<HistoryEntry>.unmodifiable(_entries);
  Duration get retention => _retention;

  static Future<HistoryController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? days = prefs.getInt(_retentionKey);
    final HistoryController c = HistoryController(
      retention: Duration(days: days ?? 7),
      prefs: prefs,
    );
    final String? raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
        c._entries = arr
            .map(
              (dynamic e) => HistoryEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        c._evictExpired();
      } catch (_) {
        c._entries = <HistoryEntry>[];
      }
    }
    return c;
  }

  Future<void> add(HistoryEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    _evictExpired();
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _entries = <HistoryEntry>[];
    notifyListeners();
    await _persist();
  }

  Future<void> setRetention(Duration retention) async {
    _retention = retention;
    _evictExpired();
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_retentionKey, retention.inDays);
    await _persist();
  }

  void _evictExpired() {
    if (_retention == Duration.zero) return;
    final DateTime cutoff = DateTime.now().subtract(_retention);
    _entries.removeWhere((HistoryEntry e) => e.timestamp.isBefore(cutoff));
  }

  Future<void> _persist() async {
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final String encoded = jsonEncode(
      _entries.map((HistoryEntry e) => e.toJson()).toList(),
    );
    await prefs.setString(_prefsKey, encoded);
  }
}

class HistoryScope extends InheritedNotifier<HistoryController> {
  const HistoryScope({
    super.key,
    required HistoryController controller,
    required super.child,
  }) : super(notifier: controller);

  static HistoryController of(BuildContext context) {
    final HistoryScope? scope = context
        .dependOnInheritedWidgetOfExactType<HistoryScope>();
    assert(scope != null, 'HistoryScope not found.');
    return scope!.notifier!;
  }
}
