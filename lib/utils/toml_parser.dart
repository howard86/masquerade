import 'package:toml/toml.dart';

sealed class TomlParseResult {
  const TomlParseResult();
}

class TomlOk extends TomlParseResult {
  const TomlOk(this.value);
  final Map<String, Object?> value;
}

class TomlErr extends TomlParseResult {
  const TomlErr({required this.message, this.line, this.column});
  final String message;
  final int? line;
  final int? column;
}

// `[section]` headers are distinctive enough alone; bare `key = value` lines
// need ≥2 so a single `FOO=bar` env-style line doesn't poach.
final RegExp _tomlTable = RegExp(r'^\[[A-Za-z_][\w.-]*\]', multiLine: true);
final RegExp _tomlKv = RegExp(r'^[A-Za-z_][\w.-]*\s*=\s', multiLine: true);

class TomlParser {
  const TomlParser._();

  /// Cheap shape heuristic — used by detectors and auto-routing before
  /// committing to the (more expensive) full parse.
  static bool looksLike(String input) {
    final String t = input.trim();
    if (_tomlTable.hasMatch(t)) return true;
    return _tomlKv.allMatches(t).take(2).length == 2;
  }

  static TomlParseResult parse(String input) {
    if (input.trim().isEmpty) {
      return const TomlErr(message: 'Empty input', line: 1);
    }
    try {
      final Map<String, dynamic> map = TomlDocument.parse(input).toMap();
      return TomlOk(_castToObjectMap(map));
    } on TomlParserException catch (e) {
      return TomlErr(message: e.message, line: e.line, column: e.column);
    } on TomlException catch (e) {
      return TomlErr(message: e.toString());
    } catch (e) {
      return TomlErr(message: e.toString());
    }
  }

  /// Encodes [value] as a TOML string. Throws [ArgumentError] when the
  /// top-level value isn't a `Map` — TOML requires a table at the root.
  static String emit(Object? value) {
    if (value is! Map) {
      throw ArgumentError(
        'TOML requires a top-level table; got ${value.runtimeType}.',
      );
    }
    return TomlDocument.fromMap(value).toString().trimRight();
  }

  static Map<String, Object?> _castToObjectMap(Map<String, dynamic> input) =>
      <String, Object?>{
        for (final MapEntry<String, dynamic> e in input.entries)
          e.key: _castValue(e.value),
      };

  static Object? _castValue(Object? v) {
    if (v is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> e in v.entries)
          e.key.toString(): _castValue(e.value),
      };
    }
    if (v is List) {
      return <Object?>[for (final Object? x in v) _castValue(x)];
    }
    if (v is DateTime) return v.toIso8601String();
    return v;
  }
}
