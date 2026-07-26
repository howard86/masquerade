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
class ToolDraftController extends ChangeNotifier {
  ToolDraftController({SharedPreferences? prefs}) : _prefs = prefs;

  static const String storageKey = 'mb.tool_drafts';
  static const int _version = 1;

  SharedPreferences? _prefs;
  Future<void> _writes = Future<void>.value();
  bool _ready = false;
  bool _suspended = false;
  int _revision = 0;
  JsonToolDraft? _json;
  DiffToolDraft? _diff;
  GeneratorToolDraft? _generator;

  bool get ready => _ready;
  int get revision => _revision;
  JsonToolDraft? get json => _json;
  DiffToolDraft? get diff => _diff;
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
    final String? safe = SensitiveDataPolicy.persistedValue(
      input,
      utilityId: 'json',
    );
    _json = safe == null || safe.isEmpty
        ? null
        : JsonToolDraft(input: safe, source: source, target: target);
    await _persist();
  }

  Future<void> saveDiff({
    required String a,
    required String b,
    required bool wordHighlight,
    required bool ignoreWhitespace,
    int? revision,
  }) async {
    if (_suspended || (revision != null && revision != _revision)) return;
    final String? safeA = SensitiveDataPolicy.persistedValue(
      a,
      utilityId: 'diff',
    );
    final String? safeB = SensitiveDataPolicy.persistedValue(
      b,
      utilityId: 'diff',
    );
    _diff = safeA == null || safeB == null || (safeA.isEmpty && safeB.isEmpty)
        ? null
        : DiffToolDraft(
            a: safeA,
            b: safeB,
            wordHighlight: wordHighlight,
            ignoreWhitespace: ignoreWhitespace,
          );
    await _persist();
  }

  Future<void> saveGenerator(GeneratorToolDraft draft, {int? revision}) async {
    if (_suspended || (revision != null && revision != _revision)) return;
    _generator = draft;
    await _persist();
  }

  Future<void> clear() async {
    _revision++;
    _json = null;
    _diff = null;
    _generator = null;
    await _enqueue((SharedPreferences prefs) => prefs.remove(storageKey));
    notifyListeners();
  }

  void suspendWrites() => _suspended = true;

  void resumeWrites() => _suspended = false;

  Future<void> _persist() async {
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

class ToolDraftScope extends InheritedNotifier<ToolDraftController> {
  const ToolDraftScope({
    super.key,
    required ToolDraftController controller,
    required super.child,
  }) : super(notifier: controller);

  static ToolDraftController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolDraftScope>()?.notifier;
}
