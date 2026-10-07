import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  HistoryEntry({
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

  /// Computed once: every field it depends on is final, and the scan (four
  /// regexes plus a decode for base64/bytes/url) is read by `_allows`,
  /// `toJson`, search, and every history row/grid-card build.
  late final bool protected = SensitiveDataPolicy.protects(
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

  /// The entry's persisted JSON, encoded once. Entries are immutable, so the
  /// string is reusable by every persist until the entry is replaced
  /// (copyWith yields a new entry and a new cache slot).
  String get encoded => _encodedCache[this] ??= jsonEncode(toJson());

  static final Expando<String> _encodedCache = Expando<String>('history.json');

  /// Lowercased searchable text (everything except the tool/date labels,
  /// which callers supply). Built on first search, then reused per keystroke.
  String get _haystack => _haystackCache[this] ??= <String>[
    utilityId,
    timestamp.toIso8601String(),
    if (!protected) ...<String>[input, output],
  ].join('\u0000').toLowerCase();

  static final Expando<String> _haystackCache = Expando<String>(
    'history.haystack',
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
///
/// Writes are debounced ([persistDelay]) and flushed when the app leaves the
/// foreground or the controller is disposed; destructive actions (delete,
/// clear, retention change) flush immediately. [flush] writes now.
class HistoryController extends ChangeNotifier with WidgetsBindingObserver {
  HistoryController({
    Duration retention = const Duration(days: 7),
    int maxEntries = 200,
    SharedPreferences? prefs,
    this.persistDelay = kIsWeb
        ? const Duration(milliseconds: 500)
        : Duration.zero,
    this.maxPersistedChars = defaultMaxPersistedChars,
  }) : _retention = retention,
       _maxEntries = maxEntries,
       _prefs = prefs;

  /// Debounce for add/pin writes. Defaults to 500 ms on web, where each write
  /// is a synchronous localStorage encode; native writes go out immediately
  /// ([Duration.zero]) since they are cheap and survive a process kill.
  final Duration persistDelay;

  /// Budget for the encoded persisted JSON. The per-entry caps allow ~16M
  /// chars, but web localStorage holds ~5M chars for the whole origin and
  /// `setItem` throws past it. Oldest unpinned entries are left out of the
  /// persisted copy (they stay in memory) until it fits.
  final int maxPersistedChars;
  static const int defaultMaxPersistedChars = 1500000;

  /// Bump when [SensitiveDataPolicy] or a tool's history policy changes what
  /// may be stored: `load` rescans stored entries only on a version mismatch.
  static const int policyVersion = 1;
  static const String _policyVersionKey = 'mb.history.policy.version';

  /// Largest input/output (UTF-16 code units) a new entry may carry. Rows
  /// reopen a tool seeded with the full stored input and copy the full
  /// output, so a truncated entry would reopen wrong; an oversized one is not
  /// recorded instead. Keeps every persist (which re-encodes all entries) and
  /// the in-memory list bounded.
  static const int maxInputLength = 16 * 1024;
  static const int maxOutputLength = 64 * 1024;

  static const String _prefsKey = 'mb.history.entries';
  static const String _retentionKey = 'mb.history.retention.days';
  static int _nextId = 0;

  Duration _retention;
  final int _maxEntries;
  SharedPreferences? _prefs;
  List<HistoryEntry> _entries = <HistoryEntry>[];
  List<HistoryEntry>? _view;
  Timer? _persistTimer;
  bool _dirty = false;
  bool _observing = false;
  int? _storedPolicyVersion;
  Future<void> _writes = Future<void>.value();

  /// Unmodifiable snapshot, rebuilt only after a mutation, so callers may
  /// compare it by identity.
  List<HistoryEntry> get entries => _view ??=
      UnmodifiableListView<HistoryEntry>(List<HistoryEntry>.of(_entries));
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
          if (entry._haystack.contains(q)) return true;
          if (toolName != null && toolName(entry).toLowerCase().contains(q)) {
            return true;
          }
          return dateLabel != null &&
              dateLabel(entry).toLowerCase().contains(q);
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
    c._storedPolicyVersion = prefs.getInt(_policyVersionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
        final bool current = c._storedPolicyVersion == policyVersion;
        final List<HistoryEntry> decoded = <HistoryEntry>[];
        for (final dynamic e in arr) {
          final HistoryEntry entry = HistoryEntry.fromJson(
            e as Map<String, dynamic>,
          );
          // Stored by this policy version: the stored text is already the
          // persisted form, so reuse it instead of re-encoding (and
          // rescanning) on the next write.
          if (current) HistoryEntry._encodedCache[entry] = jsonEncode(e);
          decoded.add(entry);
        }
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
        if (!current) {
          c._entries.removeWhere((HistoryEntry e) => !c._allows(e));
        }
        c._evictExpired();
        if (migratedIds || !current || c._entries.length != loadedCount) {
          c._dirty = true;
          unawaited(c.flush());
        }
      } catch (_) {
        c._entries = <HistoryEntry>[];
        c._dirty = true;
        unawaited(c.flush());
      }
    }
    return c;
  }

  Future<void> add(HistoryEntry entry) async {
    if (entry.input.length > maxInputLength ||
        entry.output.length > maxOutputLength) {
      return;
    }
    if (_retention == Duration.zero || !_allows(entry)) return;
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
    _view = null;
    notifyListeners();
    await _persistSoon();
  }

  bool _allows(HistoryEntry entry) =>
      historyPolicyFor(entry.utilityId) == HistoryPolicy.enabled &&
      !entry.protected;

  Future<void> clear() async {
    _entries = <HistoryEntry>[];
    _view = null;
    notifyListeners();
    _dirty = true;
    await flush();
  }

  Future<void> delete(HistoryEntry entry) async {
    final int index = _indexOf(entry);
    if (index == -1) return;
    _entries.removeAt(index);
    _view = null;
    notifyListeners();
    _dirty = true;
    await flush();
  }

  Future<void> togglePinned(HistoryEntry entry) async {
    final int index = _indexOf(entry);
    if (index == -1) return;
    final HistoryEntry current = _entries[index];
    _entries[index] = current.copyWith(pinned: !current.pinned);
    _view = null;
    notifyListeners();
    await _persistSoon();
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
    _view = null;
    notifyListeners();
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_retentionKey, retention.inDays);
    _dirty = true;
    await flush();
  }

  void _evictExpired() {
    if (_retention == Duration.zero) return;
    final DateTime cutoff = DateTime.now().subtract(_retention);
    _entries.removeWhere((HistoryEntry e) => e.timestamp.isBefore(cutoff));
  }

  Future<void> _persistSoon() {
    _dirty = true;
    if (persistDelay == Duration.zero) return flush();
    if (!_observing) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } catch (_) {
        // No binding (plain Dart test): the timer and dispose still flush.
      }
    }
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDelay, () {
      _persistTimer = null;
      unawaited(flush());
    });
    return Future<void>.value();
  }

  /// Writes any pending change now.
  Future<void> flush() {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_dirty) {
      _dirty = false;
      _writes = _writes.then((_) => _write());
    }
    return _writes;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(flush());
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    unawaited(flush());
    super.dispose();
  }

  /// The newest-first entries that fit [budget] encoded chars: oldest
  /// unpinned entries are dropped first, pinned ones only as a last resort.
  List<HistoryEntry> _within(int budget) {
    int total = 0;
    for (final HistoryEntry e in _entries) {
      total += e.encoded.length + 1;
    }
    if (total <= budget) return _entries;
    final Set<HistoryEntry> drop = Set<HistoryEntry>.identity();
    for (final bool pinnedPass in <bool>[false, true]) {
      for (int i = _entries.length - 1; i >= 0 && total > budget; i--) {
        final HistoryEntry e = _entries[i];
        if (e.pinned != pinnedPass) continue;
        drop.add(e);
        total -= e.encoded.length + 1;
      }
    }
    return <HistoryEntry>[
      for (final HistoryEntry e in _entries)
        if (!drop.contains(e)) e,
    ];
  }

  Future<void> _write() async {
    try {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      int budget = maxPersistedChars;
      while (true) {
        final String encoded =
            '[${_within(budget).map((HistoryEntry e) => e.encoded).join(',')}]';
        try {
          await prefs.setString(_prefsKey, encoded);
          break;
        } catch (e) {
          // Quota exceeded (web localStorage): retry smaller before giving up.
          if (budget < 50000) rethrow;
          budget ~/= 2;
          debugPrint('History persist failed, retrying smaller: $e');
        }
      }
      if (_storedPolicyVersion != policyVersion) {
        await prefs.setInt(_policyVersionKey, policyVersion);
        _storedPolicyVersion = policyVersion;
      }
    } catch (e) {
      debugPrint('History persist failed: $e');
    }
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

  /// The controller without subscribing to its notifications. For callers
  /// that only hold the reference (recorders) and never render history, so a
  /// history write does not rebuild them.
  static HistoryController read(BuildContext context) {
    final HistoryScope? scope = context
        .getInheritedWidgetOfExactType<HistoryScope>();
    assert(scope != null, 'HistoryScope not found.');
    return scope!.notifier!;
  }
}
