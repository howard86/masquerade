import 'dart:convert';

import 'diff_parser.dart';
import 'json_parser.dart';
import 'sensitive_data_policy.dart';
import 'yaml_parser.dart';

enum ConfigFormat { environment, properties, headers, keyValue }

class ConfigInspectorException implements Exception {
  const ConfigInspectorException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ConfigEntry {
  const ConfigEntry({
    required this.key,
    required this.value,
    required this.line,
    required this.occurrence,
    required this.exported,
  });

  final String key;
  final String value;
  final int line;
  final int occurrence;
  final bool exported;
}

class ConfigDuplicate {
  const ConfigDuplicate(this.key, this.lines);
  final String key;
  final List<int> lines;
}

class ConfigConversion {
  const ConfigConversion({this.json, this.yaml, this.warning});
  final String? json;
  final String? yaml;
  final String? warning;
  bool get available => json != null && yaml != null;
}

class ConfigComparison {
  const ConfigComparison({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unifiedDiff,
    required this.tooLarge,
  });

  final int added;
  final int removed;
  final int changed;
  final String unifiedDiff;
  final bool tooLarge;
  bool get identical => added == 0 && removed == 0 && changed == 0;
}

class ConfigInspection {
  ConfigInspection({
    required this.format,
    required List<ConfigEntry> entries,
    required List<ConfigDuplicate> duplicates,
    required this.hadSensitiveInput,
    required this.commentCount,
  }) : entries = List<ConfigEntry>.unmodifiable(entries),
       duplicates = List<ConfigDuplicate>.unmodifiable(duplicates);

  final ConfigFormat format;
  final List<ConfigEntry> entries;
  final List<ConfigDuplicate> duplicates;
  final bool hadSensitiveInput;
  final int commentCount;

  String normalized({bool sort = false}) {
    final List<({ConfigEntry entry, int index})> ordered = entries.indexed
        .map((e) => (entry: e.$2, index: e.$1))
        .toList();
    if (sort) {
      ordered.sort((a, b) {
        final int byKey =
            EnvironmentConfigInspector.canonicalKey(
              format,
              a.entry.key,
            ).compareTo(
              EnvironmentConfigInspector.canonicalKey(format, b.entry.key),
            );
        return byKey != 0 ? byKey : a.index.compareTo(b.index);
      });
    }
    return ordered.map((item) => _serialize(format, item.entry)).join('\n');
  }

  ConfigConversion convert() {
    if (duplicates.isNotEmpty) {
      return const ConfigConversion(
        warning:
            'Conversion unavailable: an object cannot preserve duplicate keys.',
      );
    }
    final Map<String, String> map = <String, String>{
      for (final ConfigEntry entry in entries) entry.key: entry.value,
    };
    final String json = JSONParser.pretty(map);
    final JSONParseResult checkedJson = JSONParser.parse(json);
    if (checkedJson is! JSONOk ||
        !_sameStringMap(checkedJson.value.value, map)) {
      return const ConfigConversion(
        warning: 'Conversion unavailable: values cannot round-trip as JSON.',
      );
    }

    String yaml = YamlParser.emit(map);
    final YamlParseResult checkedYaml = YamlParser.parse(yaml);
    if (checkedYaml is! YamlOk || !_sameStringMap(checkedYaml.value, map)) {
      // JSON is valid YAML and preserves string scalars exactly.
      yaml = json;
      final YamlParseResult fallback = YamlParser.parse(yaml);
      if (fallback is! YamlOk || !_sameStringMap(fallback.value, map)) {
        return const ConfigConversion(
          warning: 'Conversion unavailable: values cannot round-trip as YAML.',
        );
      }
    }
    final bool dropsPresentation =
        commentCount > 0 || entries.any((ConfigEntry entry) => entry.exported);
    return ConfigConversion(
      json: json,
      yaml: yaml,
      warning: dropsPresentation
          ? 'Values round-trip exactly; comments and export modifiers are not represented.'
          : null,
    );
  }

  ConfigComparison compare(ConfigInspection other) {
    final Map<String, List<ConfigEntry>> a = _byCanonicalKey(this);
    final Map<String, List<ConfigEntry>> b = _byCanonicalKey(other);
    int added = 0;
    int removed = 0;
    int changed = 0;
    for (final String key in <String>{...a.keys, ...b.keys}) {
      final List<ConfigEntry> left = a[key] ?? const <ConfigEntry>[];
      final List<ConfigEntry> right = b[key] ?? const <ConfigEntry>[];
      final int shared = left.length < right.length
          ? left.length
          : right.length;
      for (int i = 0; i < shared; i++) {
        if (left[i].value != right[i].value) changed++;
      }
      if (left.length > shared) removed += left.length - shared;
      if (right.length > shared) added += right.length - shared;
    }
    final String left = _semanticNormalized(this);
    final String right = _semanticNormalized(other);
    final DiffResult result = DiffTool.lineDiff(left, right);
    final List<DiffHunk> hunks = result.tooLarge
        ? const <DiffHunk>[]
        : DiffTool.hunkify(result.lines);
    return ConfigComparison(
      added: added,
      removed: removed,
      changed: changed,
      unifiedDiff: result.tooLarge
          ? ''
          : DiffTool.toUnifiedText(
              result,
              aLabel: 'environment-a',
              bLabel: 'environment-b',
              hunks: hunks,
            ),
      tooLarge: result.tooLarge,
    );
  }
}

class EnvironmentConfigInspector {
  const EnvironmentConfigInspector._();

  static const int maxInputCharacters = 512 * 1024;
  static const int maxLines = 10000;
  static const int maxLineCharacters = 16 * 1024;

  static ConfigInspection parse(String input, {ConfigFormat? format}) {
    if (input.isEmpty) throw const ConfigInspectorException('Empty input.');
    if (_hasUnpairedSurrogate(input)) {
      throw const ConfigInspectorException('Input contains invalid UTF-16.');
    }
    if (input.length > maxInputCharacters ||
        utf8.encode(input).length > maxInputCharacters) {
      throw const ConfigInspectorException('Input exceeds the 512 KiB limit.');
    }
    if (input.contains('\u0000')) {
      throw const ConfigInspectorException('NUL bytes are not valid config.');
    }
    final String withoutBom = input.startsWith('\uFEFF')
        ? input.substring(1)
        : input;
    final String normalized = withoutBom
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final List<String> lines = normalized.split('\n');
    if (lines.length > maxLines) {
      throw const ConfigInspectorException(
        'Input exceeds the 10,000-line limit.',
      );
    }
    if (lines.any((String line) => line.length > maxLineCharacters)) {
      throw const ConfigInspectorException('A line exceeds the 16 KiB limit.');
    }
    for (final String line in lines) {
      for (final int rune in line.runes) {
        if (rune < 0x20 && rune != 0x09) {
          throw const ConfigInspectorException(
            'Control characters are not valid config.',
          );
        }
      }
    }

    final ConfigFormat selected = format ?? detect(normalized);
    final _Parsed parsed = switch (selected) {
      ConfigFormat.environment => _parseEnvironment(lines),
      ConfigFormat.properties => _parseProperties(lines),
      ConfigFormat.headers => _parseHeaders(lines),
      ConfigFormat.keyValue => _parseKeyValue(lines),
    };
    if (parsed.values.isEmpty) {
      throw const ConfigInspectorException('No configuration entries found.');
    }

    final Map<String, List<int>> seenLines = <String, List<int>>{};
    final Map<String, int> occurrences = <String, int>{};
    final Map<String, String> displayKeys = <String, String>{};
    bool sensitive = false;
    final List<ConfigEntry> safeEntries = <ConfigEntry>[];
    for (final _Value value in parsed.values) {
      if (SensitiveDataPolicy.containsSecretLikeValue(value.key)) {
        throw const ConfigInspectorException(
          'A key contains secret-like data and was rejected.',
        );
      }
      final String canonical = canonicalKey(selected, value.key);
      displayKeys.putIfAbsent(canonical, () => value.key);
      final int occurrence = (occurrences[canonical] ?? 0) + 1;
      occurrences[canonical] = occurrence;
      seenLines.putIfAbsent(canonical, () => <int>[]).add(value.line);
      final String safe = SensitiveDataPolicy.redactedConfigValue(
        value.key,
        value.value,
      );
      sensitive |= safe != value.value;
      safeEntries.add(
        ConfigEntry(
          key: value.key,
          value: safe,
          line: value.line,
          occurrence: occurrence,
          exported: value.exported,
        ),
      );
    }
    final List<ConfigDuplicate> duplicates = <ConfigDuplicate>[
      for (final MapEntry<String, List<int>> item in seenLines.entries)
        if (item.value.length > 1)
          ConfigDuplicate(
            displayKeys[item.key]!,
            List<int>.unmodifiable(item.value),
          ),
    ];
    return ConfigInspection(
      format: selected,
      entries: safeEntries,
      duplicates: duplicates,
      hadSensitiveInput: sensitive,
      commentCount: parsed.comments,
    );
  }

  static ConfigFormat detect(String input) {
    final List<String> lines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((String line) => line.trim())
        .where(
          (String line) =>
              line.isNotEmpty && !line.startsWith('#') && !line.startsWith('!'),
        )
        .toList();
    if (lines.any((String line) => line.startsWith('export ')) ||
        lines.every(
          (String line) => RegExp(r'^[A-Z_][A-Z0-9_]*\s*=').hasMatch(line),
        )) {
      return ConfigFormat.environment;
    }
    if (lines.isNotEmpty &&
        lines.every(
          (String line) =>
              RegExp(r'''^[!#$%&'*+.^_`|~0-9A-Za-z-]+\s*:''').hasMatch(line),
        )) {
      return ConfigFormat.headers;
    }
    if (lines.any((String line) => line.contains(r'\u')) ||
        lines.any((String line) => RegExp(r'^\S+\s+\S').hasMatch(line))) {
      return ConfigFormat.properties;
    }
    return ConfigFormat.keyValue;
  }

  static String canonicalKey(ConfigFormat format, String key) =>
      format == ConfigFormat.headers ? key.toLowerCase() : key;
}

class _Parsed {
  const _Parsed(this.values, this.comments);
  final List<_Value> values;
  final int comments;
}

bool _hasUnpairedSurrogate(String value) {
  for (int i = 0; i < value.length; i++) {
    final int code = value.codeUnitAt(i);
    if (code >= 0xd800 && code <= 0xdbff) {
      if (++i >= value.length) return true;
      final int low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) return true;
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return true;
    }
  }
  return false;
}

class _Value {
  const _Value(this.key, this.value, this.line, {this.exported = false});
  final String key;
  final String value;
  final int line;
  final bool exported;
}

_Parsed _parseEnvironment(List<String> lines) {
  final List<_Value> values = <_Value>[];
  int comments = 0;
  final RegExp assignment = RegExp(
    r'^\s*(export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$',
  );
  for (int index = 0; index < lines.length; index++) {
    final int startLine = index + 1;
    String physical = lines[index];
    final String trimmed = physical.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#')) {
      comments++;
      continue;
    }
    final RegExpMatch? match = assignment.firstMatch(physical);
    if (match == null) {
      throw ConfigInspectorException(
        'Invalid environment entry on line ${index + 1}.',
      );
    }
    String valueSource = match.group(3)!;
    if ((valueSource.trimLeft().startsWith('"') ||
            valueSource.trimLeft().startsWith("'")) &&
        !_hasClosingEnvQuote(valueSource.trimLeft())) {
      while (++index < lines.length) {
        valueSource = '$valueSource\n${lines[index]}';
        if (_hasClosingEnvQuote(valueSource.trimLeft())) break;
      }
      if (!_hasClosingEnvQuote(valueSource.trimLeft())) {
        throw ConfigInspectorException(
          'Invalid quoted value on line $startLine.',
        );
      }
    } else {
      while (_oddTrailingBackslashes(valueSource) && index + 1 < lines.length) {
        valueSource =
            '${valueSource.substring(0, valueSource.length - 1)}${lines[++index].trimLeft()}';
      }
    }
    values.add(
      _Value(
        match.group(2)!,
        _decodeEnvValue(valueSource, startLine),
        startLine,
        exported: match.group(1) != null,
      ),
    );
  }
  return _Parsed(values, comments);
}

bool _hasClosingEnvQuote(String value) {
  if (value.isEmpty || (value[0] != '"' && value[0] != "'")) return true;
  final String quote = value[0];
  bool escaped = false;
  for (int i = 1; i < value.length; i++) {
    if (quote == '"' && value[i] == r'\' && !escaped) {
      escaped = true;
      continue;
    }
    if (value[i] == quote && !escaped) return true;
    escaped = false;
  }
  return false;
}

String _decodeEnvValue(String source, int line) {
  final String value = source.trim();
  if (value.isEmpty) return '';
  if (value.startsWith("'")) {
    final int end = value.indexOf("'", 1);
    if (end < 0 || !_onlyCommentAfter(value.substring(end + 1))) {
      throw ConfigInspectorException('Invalid quoted value on line $line.');
    }
    return value.substring(1, end);
  }
  if (value.startsWith('"')) {
    final StringBuffer out = StringBuffer();
    bool escaped = false;
    int end = -1;
    for (int i = 1; i < value.length; i++) {
      final String char = value[i];
      if (escaped) {
        out.write(switch (char) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          '"' => '"',
          r'$' => r'$',
          r'\' => r'\',
          _ => '\\$char',
        });
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        end = i;
        break;
      } else {
        out.write(char);
      }
    }
    if (end < 0 || escaped || !_onlyCommentAfter(value.substring(end + 1))) {
      throw ConfigInspectorException('Invalid quoted value on line $line.');
    }
    return out.toString();
  }
  final Match? comment = RegExp(r'\s+#').firstMatch(value);
  return (comment == null ? value : value.substring(0, comment.start))
      .trimRight();
}

bool _onlyCommentAfter(String suffix) {
  final String rest = suffix.trim();
  return rest.isEmpty || rest.startsWith('#');
}

_Parsed _parseProperties(List<String> physical) {
  final List<({String text, int line})> logical = <({String text, int line})>[];
  StringBuffer? current;
  int start = 0;
  for (final (int index, String line) in physical.indexed) {
    if (current == null) {
      current = StringBuffer();
      start = index + 1;
    }
    final bool continuation = _oddTrailingBackslashes(line);
    final String part = continuation
        ? line.substring(0, line.length - 1)
        : line;
    current.write(current.length == 0 ? part : part.trimLeft());
    if (!continuation) {
      logical.add((text: current.toString(), line: start));
      current = null;
    }
  }
  if (current != null) logical.add((text: current.toString(), line: start));

  final List<_Value> values = <_Value>[];
  int comments = 0;
  for (final item in logical) {
    final String left = item.text.trimLeft();
    if (left.isEmpty) continue;
    if (left.startsWith('#') || left.startsWith('!')) {
      comments++;
      continue;
    }
    final int separator = _propertySeparator(left);
    final String keySource = separator < 0
        ? left
        : left.substring(0, separator);
    int valueStart = separator < 0 ? left.length : separator;
    if (valueStart < left.length && _propertyWhitespace(left[valueStart])) {
      while (valueStart < left.length &&
          _propertyWhitespace(left[valueStart])) {
        valueStart++;
      }
      if (valueStart < left.length &&
          (left[valueStart] == '=' || left[valueStart] == ':')) {
        valueStart++;
      }
    } else if (valueStart < left.length &&
        (left[valueStart] == '=' || left[valueStart] == ':')) {
      valueStart++;
    }
    while (valueStart < left.length && _propertyWhitespace(left[valueStart])) {
      valueStart++;
    }
    final String key = _decodeProperty(keySource.trimRight(), item.line);
    if (key.isEmpty) {
      throw ConfigInspectorException(
        'Empty property key on line ${item.line}.',
      );
    }
    values.add(
      _Value(
        key,
        _decodeProperty(left.substring(valueStart), item.line),
        item.line,
      ),
    );
  }
  return _Parsed(values, comments);
}

bool _oddTrailingBackslashes(String line) {
  int count = 0;
  for (int i = line.length - 1; i >= 0 && line[i] == r'\'; i--) {
    count++;
  }
  return count.isOdd;
}

int _propertySeparator(String input) {
  bool escaped = false;
  for (int i = 0; i < input.length; i++) {
    final String char = input[i];
    if (escaped) {
      escaped = false;
    } else if (char == r'\') {
      escaped = true;
    } else if (char == '=' || char == ':' || _propertyWhitespace(char)) {
      return i;
    }
  }
  return -1;
}

bool _propertyWhitespace(String char) =>
    char == ' ' || char == '\t' || char == '\f';

String _decodeProperty(String input, int line) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final String char = input[i];
    if (char != r'\') {
      out.write(char);
      continue;
    }
    if (++i >= input.length) {
      out.write(r'\');
      break;
    }
    final String escaped = input[i];
    if (escaped == 'u') {
      if (i + 4 >= input.length) {
        throw ConfigInspectorException('Invalid Unicode escape on line $line.');
      }
      final String hex = input.substring(i + 1, i + 5);
      final int? code = int.tryParse(hex, radix: 16);
      if (code == null) {
        throw ConfigInspectorException('Invalid Unicode escape on line $line.');
      }
      out.writeCharCode(code);
      i += 4;
    } else {
      out.write(switch (escaped) {
        't' => '\t',
        'n' => '\n',
        'r' => '\r',
        'f' => '\f',
        _ => escaped,
      });
    }
  }
  return out.toString();
}

_Parsed _parseHeaders(List<String> lines) {
  final List<_Value> values = <_Value>[];
  int comments = 0;
  final RegExp name = RegExp(r"^[!#\$%&'*+.^_`|~0-9A-Za-z-]+$");
  for (final (int index, String line) in lines.indexed) {
    if (line.trim().isEmpty) continue;
    if (line.trimLeft().startsWith('#')) {
      comments++;
      continue;
    }
    if (line.startsWith(' ') || line.startsWith('\t')) {
      throw ConfigInspectorException(
        'Folded headers are not supported (line ${index + 1}).',
      );
    }
    final int colon = line.indexOf(':');
    if (colon <= 0 || !name.hasMatch(line.substring(0, colon))) {
      throw ConfigInspectorException('Invalid header on line ${index + 1}.');
    }
    values.add(
      _Value(
        line.substring(0, colon),
        line.substring(colon + 1).trim(),
        index + 1,
      ),
    );
  }
  return _Parsed(values, comments);
}

_Parsed _parseKeyValue(List<String> lines) {
  final List<_Value> values = <_Value>[];
  int comments = 0;
  for (final (int index, String line) in lines.indexed) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#') || trimmed.startsWith(';')) {
      comments++;
      continue;
    }
    final int equals = line.indexOf('=');
    final int colon = line.indexOf(':');
    final int separator = equals < 0
        ? colon
        : colon < 0
        ? equals
        : (equals < colon ? equals : colon);
    if (separator <= 0) {
      throw ConfigInspectorException(
        'Invalid key/value entry on line ${index + 1}.',
      );
    }
    final String key = line.substring(0, separator).trim();
    if (key.isEmpty || key.runes.any((int rune) => rune < 0x20)) {
      throw ConfigInspectorException('Invalid key on line ${index + 1}.');
    }
    values.add(
      _Value(
        key,
        _decodeEnvValue(line.substring(separator + 1), index + 1),
        index + 1,
      ),
    );
  }
  return _Parsed(values, comments);
}

String _serialize(ConfigFormat format, ConfigEntry entry) {
  final String value = entry.value;
  return switch (format) {
    ConfigFormat.environment =>
      '${entry.exported ? 'export ' : ''}${entry.key}=${_quoteEnv(value)}',
    ConfigFormat.properties =>
      '${_escapeProperty(entry.key, key: true)}=${_escapeProperty(value)}',
    ConfigFormat.headers => '${entry.key}: $value',
    ConfigFormat.keyValue => '${entry.key}=${_quoteEnv(value)}',
  };
}

String _quoteEnv(String value) {
  if (value.isEmpty) return "''";
  if (RegExp(r'^[A-Za-z0-9_./:@%+,-]+$').hasMatch(value)) return value;
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\t', r'\t').replaceAll(r'$', r'\$')}"';
}

String _escapeProperty(String value, {bool key = false}) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    final String char = value[i];
    final int code = value.codeUnitAt(i);
    if ((code < 0x20 &&
            code != 0x09 &&
            code != 0x0a &&
            code != 0x0c &&
            code != 0x0d) ||
        (code >= 0xd800 && code <= 0xdfff)) {
      out.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
      continue;
    }
    out.write(switch (char) {
      r'\' => r'\\',
      '\t' => r'\t',
      '\n' => r'\n',
      '\r' => r'\r',
      '\f' => r'\f',
      '=' when key => r'\=',
      ':' when key => r'\:',
      ' ' when key || i == 0 => r'\ ',
      '#' when key && i == 0 => r'\#',
      '!' when key && i == 0 => r'\!',
      _ => char,
    });
  }
  return out.toString();
}

bool _sameStringMap(Object? value, Map<String, String> expected) {
  if (value is! Map || value.length != expected.length) return false;
  for (final MapEntry<String, String> entry in expected.entries) {
    if (value[entry.key] is! String || value[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

Map<String, List<ConfigEntry>> _byCanonicalKey(ConfigInspection inspection) {
  final Map<String, List<ConfigEntry>> result = <String, List<ConfigEntry>>{};
  for (final ConfigEntry entry in inspection.entries) {
    final String key = EnvironmentConfigInspector.canonicalKey(
      inspection.format,
      entry.key,
    );
    result.putIfAbsent(key, () => <ConfigEntry>[]).add(entry);
  }
  return result;
}

String _semanticNormalized(ConfigInspection inspection) {
  final List<({String key, String value, int occurrence})> values =
      <({String key, String value, int occurrence})>[
        for (final ConfigEntry entry in inspection.entries)
          (
            key: EnvironmentConfigInspector.canonicalKey(
              inspection.format,
              entry.key,
            ),
            value: entry.value,
            occurrence: entry.occurrence,
          ),
      ]..sort((a, b) {
        final int key = a.key.compareTo(b.key);
        return key != 0 ? key : a.occurrence.compareTo(b.occurrence);
      });
  return values
      .map((item) => '${jsonEncode(item.key)}=${jsonEncode(item.value)}')
      .join('\n');
}
