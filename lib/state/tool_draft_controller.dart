import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/sensitive_data_policy.dart';
import '../utils/generator.dart';

class JsonToolDraft {
  const JsonToolDraft({
    required this.input,
    required this.source,
    required this.target,
  });

  final String input;
  final String source;
  final String target;
}

class DiffToolDraft {
  const DiffToolDraft({
    required this.a,
    required this.b,
    required this.wordHighlight,
    required this.ignoreWhitespace,
  });

  final String a;
  final String b;
  final bool wordHighlight;
  final bool ignoreWhitespace;
}

class GeneratorToolDraft {
  const GeneratorToolDraft({
    required this.mode,
    required this.length,
    required this.bytes,
    required this.lower,
    required this.upper,
    required this.digits,
    required this.symbols,
    required this.tokenFormat,
    required this.uuidVersion,
  });

  final String mode;
  final int length;
  final int bytes;
  final bool lower;
  final bool upper;
  final bool digits;
  final bool symbols;
  final String tokenFormat;
  final String uuidVersion;
}

/// The three explicit draft codecs shipped by the initial workflow tools.
///
/// Saves are cheap and run per keystroke: they record the latest values and
/// defer both the sensitivity scan and the prefs write to a trailing
/// [persistDelay] timer. Reads resolve any pending value first, so a getter
/// never exposes content the scan would drop. [flush] writes immediately;
/// [ToolDraftScope] calls it when the app pauses and when the scope unmounts.
class ToolDraftController extends ChangeNotifier {
  ToolDraftController({
    SharedPreferences? prefs,
    this.persistDelay = const Duration(milliseconds: 500),
  }) : _prefs = prefs;

  static const String storageKey = 'mb.tool_drafts';
  static const int _version = 1;

  /// Idle time after the last save before drafts are written to prefs.
  final Duration persistDelay;

  SharedPreferences? _prefs;
  Future<void> _writes = Future<void>.value();
  Timer? _persistTimer;
  bool _dirty = false;
  bool _ready = false;
  bool _suspended = false;
  int _revision = 0;
  JsonToolDraft? _json;
  DiffToolDraft? _diff;
  GeneratorToolDraft? _generator;
  JsonToolDraft? _pendingJson;
  DiffToolDraft? _pendingDiff;

  bool get ready => _ready;
  int get revision => _revision;
  JsonToolDraft? get json {
    _resolvePending();
    return _json;
  }

  DiffToolDraft? get diff {
    _resolvePending();
    return _diff;
  }

  GeneratorToolDraft? get generator => _generator;

  static Future<ToolDraftController> load() async {
    final ToolDraftController controller = ToolDraftController();
    await controller.attach();
    return controller;
  }

  Future<void> attach() async {
    if (_ready) return;
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final String? raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is! Map || decoded['version'] != _version) {
          throw const FormatException('Unsupported tool draft');
        }
        _json = _decodeJson(decoded['json']);
        _diff = _decodeDiff(decoded['diff']);
        _generator = _decodeGenerator(decoded['generator']);
        await _persist();
      } catch (_) {
        await prefs.remove(storageKey);
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> saveJson({
    required String input,
    required String source,
    required String target,
    int? revision,
  }) async {
    if (_suspended || (revision != null && revision != _revision)) return;
    _pendingJson = JsonToolDraft(input: input, source: source, target: target);
    _schedulePersist();
  }

  Future<void> saveDiff({
    required String a,
    required String b,
    required bool wordHighlight,
    required bool ignoreWhitespace,
    int? revision,
  }) async {
    if (_suspended || (revision != null && revision != _revision)) return;
    _pendingDiff = DiffToolDraft(
      a: a,
      b: b,
      wordHighlight: wordHighlight,
      ignoreWhitespace: ignoreWhitespace,
    );
    _schedulePersist();
  }

  Future<void> saveGenerator(GeneratorToolDraft draft, {int? revision}) async {
    if (_suspended || (revision != null && revision != _revision)) return;
    _generator = draft;
    _schedulePersist();
  }

  /// Writes any unsaved draft now instead of waiting for [persistDelay].
  Future<void> flush() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!_dirty || _suspended) return;
    await _persist();
  }

  Future<void> clear() async {
    _revision++;
    _persistTimer?.cancel();
    _persistTimer = null;
    _dirty = false;
    _pendingJson = null;
    _pendingDiff = null;
    _json = null;
    _diff = null;
    _generator = null;
    await _enqueue((SharedPreferences prefs) => prefs.remove(storageKey));
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(flush());
    super.dispose();
  }

  void suspendWrites() => _suspended = true;

  void resumeWrites() => _suspended = false;

  void _schedulePersist() {
    _dirty = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDelay, () {
      _persistTimer = null;
      if (_dirty && !_suspended) unawaited(_persist());
    });
  }

  /// Applies the sensitivity gate to values saved since the last read/write.
  void _resolvePending() {
    if (_pendingJson case final JsonToolDraft d) {
      _pendingJson = null;
      final String? safe = SensitiveDataPolicy.persistedValue(
        d.input,
        utilityId: 'json',
      );
      _json = safe == null || safe.isEmpty ? null : d;
    }
    if (_pendingDiff case final DiffToolDraft d) {
      _pendingDiff = null;
      final String? safeA = SensitiveDataPolicy.persistedValue(
        d.a,
        utilityId: 'diff',
      );
      final String? safeB = SensitiveDataPolicy.persistedValue(
        d.b,
        utilityId: 'diff',
      );
      _diff = safeA == null || safeB == null || (safeA.isEmpty && safeB.isEmpty)
          ? null
          : d;
    }
  }

  Future<void> _persist() async {
    _resolvePending();
    _dirty = false;
    final Map<String, Object?> payload = <String, Object?>{
      'version': _version,
      if (_json case final JsonToolDraft d)
        'json': <String, Object>{
          'input': d.input,
          'source': d.source,
          'target': d.target,
        },
      if (_diff case final DiffToolDraft d)
        'diff': <String, Object>{
          'a': d.a,
          'b': d.b,
          'wordHighlight': d.wordHighlight,
          'ignoreWhitespace': d.ignoreWhitespace,
        },
      if (_generator case final GeneratorToolDraft d)
        'generator': <String, Object>{
          'mode': d.mode,
          'length': d.length,
          'bytes': d.bytes,
          'lower': d.lower,
          'upper': d.upper,
          'digits': d.digits,
          'symbols': d.symbols,
          'tokenFormat': d.tokenFormat,
          'uuidVersion': d.uuidVersion,
        },
    };
    if (payload.length == 1) {
      await _enqueue((SharedPreferences prefs) => prefs.remove(storageKey));
    } else {
      final String encoded = jsonEncode(payload);
      await _enqueue(
        (SharedPreferences prefs) => prefs.setString(storageKey, encoded),
      );
    }
  }

  Future<void> _enqueue(
    Future<bool> Function(SharedPreferences prefs) operation,
  ) {
    final Future<void> next = _writes.then((_) async {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await operation(prefs);
    });
    _writes = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  static JsonToolDraft? _decodeJson(Object? raw) {
    if (raw is! Map ||
        raw['input'] is! String ||
        !const <String>{
          'auto',
          'json',
          'yaml',
          'toml',
        }.contains(raw['source']) ||
        !const <String>{
          'prettyJson',
          'minifiedJson',
          'tree',
          'yaml',
          'toml',
        }.contains(raw['target'])) {
      return null;
    }
    final String input = raw['input'] as String;
    if (SensitiveDataPolicy.persistedValue(input, utilityId: 'json') == null) {
      return null;
    }
    return JsonToolDraft(
      input: input,
      source: raw['source'] as String,
      target: raw['target'] as String,
    );
  }

  static DiffToolDraft? _decodeDiff(Object? raw) {
    if (raw is! Map ||
        raw['a'] is! String ||
        raw['b'] is! String ||
        raw['wordHighlight'] is! bool ||
        raw['ignoreWhitespace'] is! bool) {
      return null;
    }
    final String a = raw['a'] as String;
    final String b = raw['b'] as String;
    if (SensitiveDataPolicy.persistedValue(a, utilityId: 'diff') == null ||
        SensitiveDataPolicy.persistedValue(b, utilityId: 'diff') == null) {
      return null;
    }
    return DiffToolDraft(
      a: a,
      b: b,
      wordHighlight: raw['wordHighlight'] as bool,
      ignoreWhitespace: raw['ignoreWhitespace'] as bool,
    );
  }

  static GeneratorToolDraft? _decodeGenerator(Object? raw) {
    if (raw is! Map ||
        !const <String>{'password', 'token', 'uuid'}.contains(raw['mode']) ||
        raw['length'] is! int ||
        raw['bytes'] is! int ||
        raw['lower'] is! bool ||
        raw['upper'] is! bool ||
        raw['digits'] is! bool ||
        raw['symbols'] is! bool ||
        !const <String>{
          'hex',
          'base64url',
          'alphanumeric',
        }.contains(raw['tokenFormat']) ||
        !const <String>{'v4', 'v7'}.contains(raw['uuidVersion'])) {
      return null;
    }
    final int length = raw['length'] as int;
    final int bytes = raw['bytes'] as int;
    if (length < Generator.minLength ||
        length > Generator.maxLength ||
        bytes < Generator.minBytes ||
        bytes > Generator.maxBytes) {
      return null;
    }
    return GeneratorToolDraft(
      mode: raw['mode'] as String,
      length: length,
      bytes: bytes,
      lower: raw['lower'] as bool,
      upper: raw['upper'] as bool,
      digits: raw['digits'] as bool,
      symbols: raw['symbols'] as bool,
      tokenFormat: raw['tokenFormat'] as String,
      uuidVersion: raw['uuidVersion'] as String,
    );
  }
}

/// Provides the [ToolDraftController] and flushes its debounced writes when
/// the app leaves the foreground or the scope unmounts, so a pending draft is
/// not lost to process death.
class ToolDraftScope extends StatefulWidget {
  const ToolDraftScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final ToolDraftController controller;
  final Widget child;

  static ToolDraftController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ToolDraftInherited>()
      ?.notifier;

  @override
  State<ToolDraftScope> createState() => _ToolDraftScopeState();
}

class _ToolDraftScopeState extends State<ToolDraftScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ToolDraftScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      unawaited(oldWidget.controller.flush());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.flush());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ToolDraftInherited(controller: widget.controller, child: widget.child);
}

class _ToolDraftInherited extends InheritedNotifier<ToolDraftController> {
  const _ToolDraftInherited({
    required ToolDraftController controller,
    required super.child,
  }) : super(notifier: controller);
}
