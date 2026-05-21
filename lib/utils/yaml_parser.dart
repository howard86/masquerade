import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

sealed class YamlParseResult {
  const YamlParseResult();
}

class YamlOk extends YamlParseResult {
  const YamlOk(this.value, this.docCount);
  final Object? value;
  final int docCount;
}

class YamlErr extends YamlParseResult {
  const YamlErr({required this.message, this.line, this.column});
  final String message;
  final int? line;
  final int? column;
}

// `---` document separator is unambiguous; bare `key:` lines need ≥2 because
// a single `key: value` could just as easily be a typo or a fragment.
final RegExp _yamlKey = RegExp(
  r'^[ \t]*[A-Za-z_][\w.-]*\s*:\s',
  multiLine: true,
);

class YamlParser {
  const YamlParser._();

  /// Cheap shape heuristic — used by detectors and auto-routing before
  /// committing to the (more expensive) full parse.
  static bool looksLike(String input) {
    final String t = input.trim();
    if (t.startsWith('---')) return true;
    return _yamlKey.allMatches(t).take(2).length == 2;
  }

  /// Parses [input] as a YAML stream. When multiple documents are present
  /// (separated by `---`), only the first document's value is returned and
  /// [YamlOk.docCount] reflects the total count so the body can surface a
  /// "showing 1 of N" chip.
  static YamlParseResult parse(String input) {
    if (input.trim().isEmpty) {
      return const YamlErr(message: 'Empty input', line: 1);
    }
    try {
      final List<YamlDocument> docs = loadYamlDocuments(input);
      if (docs.isEmpty) {
        return const YamlErr(message: 'No documents found');
      }
      return YamlOk(_unwrap(docs.first.contents.value), docs.length);
    } on YamlException catch (e) {
      // `SourceSpan.start.line/column` is 0-based; users expect 1-based.
      final start = e.span?.start;
      return YamlErr(
        message: e.message,
        line: start == null ? null : start.line + 1,
        column: start == null ? null : start.column + 1,
      );
    } catch (e) {
      return YamlErr(message: e.toString());
    }
  }

  /// Encodes [value] as a YAML string. Strings stay unquoted when safe so
  /// the output matches the YAML idiom users expect when pasting JSON.
  static String emit(Object? value) {
    final String written = YamlWriter(allowUnquotedStrings: true).write(value);
    return written.trimRight();
  }

  /// Converts YAML wrapper types (`YamlMap`, `YamlList`) into plain Dart
  /// `Map`/`List` so downstream encoders (`jsonEncode`, `TomlDocument`) can
  /// consume them without special-casing.
  static Object? _unwrap(Object? node) {
    if (node is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> e in node.entries)
          e.key.toString(): _unwrap(e.value),
      };
    }
    if (node is List) {
      return <Object?>[for (final Object? v in node) _unwrap(v)];
    }
    return node;
  }
}
