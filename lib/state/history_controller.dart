import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility_catalog.dart';
import '../utils/sensitive_data_policy.dart';

HistoryPolicy historyPolicyFor(String utilityId) =>
    UtilityCatalog.byIdOrNull(utilityId)?.historyPolicy ??
    HistoryPolicy.disabled;

/// One captured utility action.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.utilityId,
    required this.input,
    required this.output,
    required this.timestamp,
    this.sensitive = false,
    this.pinned = false,
    this.sessionId,
    this.id,
  });

  final String utilityId;
  final String input;
  final String output;
  final DateTime timestamp;
  final bool sensitive;
  final bool pinned;
  final String? sessionId;
  final String? id;

  bool get protected => SensitiveDataPolicy.protects(
    utilityId: utilityId,
    sensitive: sensitive,
    values: <String>[input, output],
  );

  HistoryEntry copyWith({bool? pinned, String? id}) => HistoryEntry(
    utilityId: utilityId,
    input: input,
    output: output,
    timestamp: timestamp,
    sensitive: sensitive,
    pinned: pinned ?? this.pinned,
    sessionId: sessionId,
    id: id ?? this.id,
  );

  Map<String, dynamic> toJson() {
    final bool redact = protected;
    return <String, dynamic>{
      'utilityId': utilityId,
      'input': redact ? '' : input,
      'output': redact ? '' : output,
      'ts': timestamp.millisecondsSinceEpoch,
      'sensitive': redact,
      'pinned': pinned,
      if (sessionId != null) 'sessionId': sessionId,
      if (id != null) 'id': id,
    };
  }

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
    utilityId: json['utilityId'] as String,
    input: json['input'] as String,
    output: json['output'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    sensitive: json['sensitive'] as bool? ?? false,
    pinned: json['pinned'] as bool? ?? false,
    sessionId: json['sessionId'] as String?,
    id: json['id'] as String?,
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
  static int _nextId = 0;

  Duration _retention;
  final int _maxEntries;
  SharedPreferences? _prefs;
  List<HistoryEntry> _entries = <HistoryEntry>[];

  List<HistoryEntry> get entries => List<HistoryEntry>.unmodifiable(_entries);
  Duration get retention => _retention;

  List<HistoryEntry> search(
    String query, {
    String Function(HistoryEntry entry)? toolName,
    String Function(HistoryEntry entry)? dateLabel,
  }) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return _entries
        .where((HistoryEntry entry) {
          final Iterable<String> searchable = <String>[
            entry.utilityId,
            if (toolName != null) toolName(entry),
            entry.timestamp.toIso8601String(),
            if (dateLabel != null) dateLabel(entry),
            if (!entry.protected) ...<String>[entry.input, entry.output],
          ];
          return searchable.any(
            (String value) => value.toLowerCase().contains(q),
          );
        })
        .toList(growable: false);
  }

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
        final List<HistoryEntry> decoded = arr
            .map(
              (dynamic e) => HistoryEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        final bool migratedIds = decoded.any(
          (HistoryEntry entry) => entry.id == null,
        );
        c._entries = decoded
            .map(
              (HistoryEntry entry) =>
                  entry.id == null ? entry.copyWith(id: _newId()) : entry,
            )
            .toList();
        final int loadedCount = c._entries.length;
        c._entries.removeWhere((HistoryEntry e) => !c._allows(e));
        c._evictExpired();
        if (migratedIds || c._entries.length != loadedCount) {
          await c._persist();
        }
      } catch (_) {
        c._entries = <HistoryEntry>[];
        await c._persist();
      }
    }
    return c;
  }

  Future<void> add(HistoryEntry entry) async {
    if (!_allows(entry)) return;
    // Dedupe: skip when the most recent entry shares utilityId + input.
    // Tools are deterministic (same input → same output), so consecutive
    // adds carry no new information. Mode flips that re-derive output from
    // the same input (e.g. Base64 encode→decode without _swap) dedupe to
    // a single entry; the _swap path swaps controller.text, which yields a
    // distinct input and records both directions.
    if (_entries.isNotEmpty &&
        _entries.first.utilityId == entry.utilityId &&
        _entries.first.input == entry.input) {
      return;
    }
    _entries.insert(0, entry.id == null ? entry.copyWith(id: _newId()) : entry);
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    _evictExpired();
    notifyListeners();
    await _persist();
  }

  bool _allows(HistoryEntry entry) =>
      historyPolicyFor(entry.utilityId) == HistoryPolicy.enabled &&
      !entry.protected;

  Future<void> clear() async {
    _entries = <HistoryEntry>[];
    notifyListeners();
    await _persist();
  }

  Future<void> delete(HistoryEntry entry) async {
    final int index = _indexOf(entry);
    if (index == -1) return;
    _entries.removeAt(index);
    notifyListeners();
    await _persist();
  }

  Future<void> togglePinned(HistoryEntry entry) async {
    final int index = _indexOf(entry);
    if (index == -1) return;
    final HistoryEntry current = _entries[index];
    _entries[index] = current.copyWith(pinned: !current.pinned);
    notifyListeners();
    await _persist();
  }

  int _indexOf(HistoryEntry entry) {
    if (entry.id != null) {
      return _entries.indexWhere(
        (HistoryEntry candidate) => candidate.id == entry.id,
      );
    }
    return _entries.indexWhere(
      (HistoryEntry candidate) =>
          identical(candidate, entry) ||
          (candidate.utilityId == entry.utilityId &&
              candidate.input == entry.input &&
              candidate.output == entry.output &&
              candidate.timestamp == entry.timestamp &&
              candidate.sessionId == entry.sessionId),
    );
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_nextId++}';

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
