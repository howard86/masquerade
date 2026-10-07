import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'encoding_parser.dart';
import 'sensitive_data_policy.dart';
import 'utf8_length.dart';

enum LogLevel { trace, debug, info, warn, error, fatal, unknown }

class LogInspectorException implements Exception {
  const LogInspectorException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LogEvent {
  const LogEvent._({
    required this.startLine,
    required this.endLine,
    required this.level,
    required this.text,
    required this.artifacts,
    this.timestampUtc,
  });

  final int startLine;
  final int endLine;
  final LogLevel level;
  final DateTime? timestampUtc;
  final String text;
  final List<String> artifacts;

  String get normalizedTimestamp => timestampUtc?.toIso8601String() ?? '';
}

class LogInspection {
  const LogInspection._({
    required this.events,
    required this.truncated,
    required this.hadSensitiveInput,
  });

  final List<LogEvent> events;
  final bool truncated;
  final bool hadSensitiveInput;

  List<LogEvent> filter({
    Set<LogLevel> levels = const <LogLevel>{},
    String query = '',
  }) {
    if (query.length > LogStackInspector.maxSearchCharacters) {
      throw const LogInspectorException('Search is too long.');
    }
    final RegExp? needle = query.isEmpty
        ? null
        : RegExp(RegExp.escape(query), caseSensitive: false, unicode: true);
    return List<LogEvent>.unmodifiable(
      events.where(
        (LogEvent event) =>
            (levels.isEmpty || levels.contains(event.level)) &&
            (needle == null || needle.hasMatch(event.text)),
      ),
    );
  }

  String export(Iterable<LogEvent> selection) {
    final Set<LogEvent> selected = selection.toSet();
    return events
        .where(selected.contains)
        .map((LogEvent event) => LogStackInspector._redactText(event.text))
        .join('\n');
  }
}

abstract final class LogStackInspector {
  static const int maxInputCharacters = 524288;
  static const int maxInputBytes = 524288;
  static const int maxLines = 10000;
  static const int maxEvents = 5000;
  static const int maxLineCharacters = 16384;
  static const int maxSearchCharacters = 256;
  static const int _maxJsonDepth = 12;
  static const int _maxJsonNodes = 2048;

  static final RegExp _isoTimestamp = RegExp(
    r'(?<!\d)(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)(?!\d)',
  );
  static final RegExp _bracketTimestamp = RegExp(
    r'^\[(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]',
  );
  static final RegExp _epochTimestamp = RegExp(r'(?<!\d)(\d{10}|\d{13})(?!\d)');
  static final RegExp _secretKey = RegExp(
    r'(?:api[-_.]?key|access[-_.]?token|auth(?:orization)?|client[-_.]?secret|cookie|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|refresh[-_.]?token|secret(?:[-_.]?(?:access[-_.]?)?key)?|session[-_.]?token|token)',
    caseSensitive: false,
  );
  static final RegExp _privateKeyBegin = RegExp(
    r'-----BEGIN [^-\r\n]*PRIVATE KEY[^-\r\n]*-----',
    caseSensitive: false,
  );
  static final RegExp _privateKeyEnd = RegExp(
    r'-----END [^-\r\n]*PRIVATE KEY[^-\r\n]*-----',
    caseSensitive: false,
  );
  static final RegExp _authorization = RegExp(
    r'((?:proxy-)?authorization\s*[:=]\s*)(?:bearer|basic)?\s*[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _standaloneAuthorization = RegExp(
    r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _cookie = RegExp(
    r'((?:set-)?cookie\s*:\s*)[^\r\n]+',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*',
  );
  static final RegExp _awsKey = RegExp(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b');
  static final RegExp _providerToken = RegExp(
    r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})\b',
    caseSensitive: false,
  );
  static final RegExp _urlUserInfo = RegExp(
    r'([A-Za-z][A-Za-z0-9+.-]*://)[^/@\s]+@',
  );
  static final RegExp _assignment = RegExp(
    r'''(["']?(?:api[-_.]?key|access[-_.]?token|auth(?:orization)?|client[-_.]?secret|cookie|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|refresh[-_.]?token|secret(?:[-_.]?(?:access[-_.]?)?key)?|session[-_.]?token|token)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s&,;]+)''',
    caseSensitive: false,
  );
  static final RegExp _querySecret = RegExp(
    r'([?&](?:api[-_.]?key|access[-_.]?token|auth(?:orization)?|client[-_.]?secret|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|refresh[-_.]?token|secret(?:[-_.]?(?:access[-_.]?)?key)?|session[-_.]?token|token)=)[^&#\s]*',
    caseSensitive: false,
  );
  static final RegExp _url = RegExp(r'https?://[^\s<>"\]]+');
  static final RegExp _uuid = RegExp(
    r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-8][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}(?![0-9A-Fa-f])',
  );
  static final RegExp _hex = RegExp(
    r'(?<![0-9A-Fa-f])(?:0x)?(?:[0-9A-Fa-f]{128}|[0-9A-Fa-f]{64}|[0-9A-Fa-f]{40}|[0-9A-Fa-f]{32})(?![0-9A-Fa-f])',
  );
  static final RegExp _base64 = RegExp(
    r'(?<![A-Za-z0-9_-])[A-Za-z0-9_+/-]{12,}={0,2}(?![A-Za-z0-9_=-])',
  );
  static final RegExp _frameNumber = RegExp(r'^(?:#\d+|\d+:)\s');
  static final RegExp _exceptionName = RegExp(r'(?:Exception|Error)(?::|$)');
  static final RegExp _exceptionLine = RegExp(
    r'^(?:[A-Za-z_.]+)?(?:Exception|Error)(?::|$)',
  );
  static final RegExp _levelWord = RegExp(
    r'^[\[(]?(TRACE|DEBUG|INFO|WARN(?:ING)?|ERROR|FATAL)(?:[\])\s:|-]|$)',
    caseSensitive: false,
  );
  static final RegExp _isoFields = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})',
  );
  static final RegExp _zoneSuffix = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$');
  static final RegExp _epochLine = RegExp(r'^(\d{10}|\d{13})(?:\s|$)');
  static final RegExp _percentEncoded = RegExp(
    r'(?<![A-Za-z0-9._~%-])(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})*%[0-9A-Fa-f]{2}(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})*(?![A-Za-z0-9._~%-])',
  );

  static LogInspection parse(String input) {
    if (input.length > maxInputCharacters) {
      throw const LogInspectorException('Log exceeds the 512 KiB limit.');
    }
    if (input.contains('\u0000')) {
      throw const LogInspectorException('Log contains unsupported NUL bytes.');
    }
    if (utf8LengthExceeds(input, maxInputBytes)) {
      throw const LogInspectorException('Log exceeds the 512 KiB limit.');
    }

    final String stripped = _stripAnsi(
      input,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> sourceLines = stripped.split('\n');
    if (sourceLines.length > maxLines) {
      throw const LogInspectorException('Log exceeds the 10,000-line limit.');
    }
    if (sourceLines.any((String line) => line.length > maxLineCharacters)) {
      throw const LogInspectorException('A log line exceeds the 16 KiB limit.');
    }

    final List<_SafeLine> lines = <_SafeLine>[];
    int? privateKeyStart;
    bool hadSensitiveInput = false;
    for (final (int index, String raw) in sourceLines.indexed) {
      if (_privateKeyBegin.hasMatch(raw)) {
        privateKeyStart = index + 1;
        hadSensitiveInput = true;
      }
      if (privateKeyStart == null) {
        final _SafeLine line = _safeLine(index + 1, raw);
        lines.add(line);
        hadSensitiveInput |= line.redacted;
      } else if (_privateKeyEnd.hasMatch(raw)) {
        lines.add(
          _SafeLine(
            privateKeyStart,
            '[REDACTED PRIVATE KEY]',
            endNumber: index + 1,
            redacted: true,
          ),
        );
        privateKeyStart = null;
      }
    }
    if (privateKeyStart != null) {
      throw const LogInspectorException('Unterminated private-key block.');
    }

    final List<LogEvent> events = <LogEvent>[];
    _EventBuilder? current;
    bool truncated = false;
    for (final _SafeLine line in lines) {
      if (current == null || !_continues(line, current)) {
        if (current != null) {
          events.add(current.build());
          if (events.length >= maxEvents) {
            current = null;
            truncated = true;
            break;
          }
        }
        current = _EventBuilder(line);
      } else {
        current.add(line);
      }
    }
    if (current != null) events.add(current.build());
    return LogInspection._(
      events: List<LogEvent>.unmodifiable(events),
      truncated: truncated,
      hadSensitiveInput: hadSensitiveInput,
    );
  }

  static _SafeLine _safeLine(int number, String raw) {
    final String trimmed = raw.trimLeft();
    final bool mayBeJson = trimmed.startsWith('{') || trimmed.startsWith('[');
    if (mayBeJson && !_jsonWithinBounds(trimmed)) {
      return _SafeLine(number, '[TRUNCATED JSON]', json: true, redacted: true);
    }
    Object? decoded;
    if (mayBeJson) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        decoded = null;
      }
    }
    if (decoded is Map || decoded is List) {
      final _JsonBudget budget = _JsonBudget();
      final Object? redacted = _redactJson(decoded, 0, budget);
      final String text = jsonEncode(redacted);
      return _SafeLine(
        number,
        text,
        json: true,
        level: _jsonLevel(redacted),
        timestamp: _jsonTimestamp(redacted),
        redacted: budget.redacted,
      );
    }
    final String safe = _redactText(raw);
    final ({LogLevel level, bool leadingTimestamp}) prefix = _detectPrefix(
      safe,
    );
    return _SafeLine(
      number,
      safe,
      level: prefix.level,
      leadingTimestamp: prefix.leadingTimestamp,
      timestamp: _detectTimestamp(safe),
      redacted: safe != raw,
    );
  }

  static bool _jsonWithinBounds(String value) {
    int depth = 0;
    int nodes = 0;
    bool quoted = false;
    bool escaped = false;
    for (final int code in value.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (code == 0x22) {
        quoted = true;
      } else if (code == 0x7b || code == 0x5b) {
        if (++depth > _maxJsonDepth || ++nodes > _maxJsonNodes) return false;
      } else if (code == 0x7d || code == 0x5d) {
        if (--depth < 0) return true;
      }
    }
    return true;
  }

  static Object? _redactJson(Object? value, int depth, _JsonBudget budget) {
    if (depth > _maxJsonDepth || ++budget.nodes > _maxJsonNodes) {
      budget.redacted = true;
      return '[TRUNCATED]';
    }
    if (value is Map) {
      final Map<String, Object?> safe = <String, Object?>{};
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        final String rawKey = entry.key.toString();
        String key = _redactText(rawKey);
        budget.redacted |= key != rawKey;
        if (safe.containsKey(key)) key = '$key #${safe.length + 1}';
        safe[key] = _redactJsonEntry(entry, depth, budget);
      }
      return safe;
    }
    if (value is List) {
      return value
          .map((Object? item) => _redactJson(item, depth + 1, budget))
          .toList(growable: false);
    }
    if (value is String) {
      final String safe = _redactText(value);
      budget.redacted |= safe != value;
      return safe;
    }
    return value;
  }

  static Object? _redactJsonEntry(
    MapEntry<Object?, Object?> entry,
    int depth,
    _JsonBudget budget,
  ) {
    if (_secretKey.hasMatch(entry.key.toString())) {
      budget.redacted = true;
      return SensitiveDataPolicy.mask;
    }
    return _redactJson(entry.value, depth + 1, budget);
  }

  /// [_redactText] with the literal pre-checks on or off, so tests can prove
  /// the pre-checks never skip a pass that would have matched.
  @visibleForTesting
  static String redactTextForTest(String value, {required bool precheck}) =>
      _redactText(value, precheck: precheck);

  static String _redactText(String value, {bool precheck = true}) {
    // Each pass below can only match text containing a literal it requires
    // (case-insensitively where the pass is). Replacements only splice in
    // mask characters and text already in [value], so a literal absent from
    // [value] is absent at every later pass too, and that pass is a no-op.
    final String lower = precheck ? value.toLowerCase() : '';
    bool has(String literal) => !precheck || lower.contains(literal);
    bool hasExact(String literal) => !precheck || value.contains(literal);
    final bool secretName =
        has('key') ||
        has('token') ||
        has('auth') ||
        has('secret') ||
        has('credential') ||
        has('pass');
    String safe = value;
    if (has('authorization')) {
      safe = safe.replaceAllMapped(
        _authorization,
        (Match m) => '${m[1]}${SensitiveDataPolicy.mask}',
      );
    }
    if (has('cookie')) {
      safe = safe.replaceAllMapped(
        _cookie,
        (Match m) => '${m[1]}${SensitiveDataPolicy.mask}',
      );
    }
    if (has('bearer') || has('basic')) {
      safe = safe.replaceAll(
        _standaloneAuthorization,
        SensitiveDataPolicy.mask,
      );
    }
    if (hasExact('eyJ')) {
      safe = safe.replaceAll(_jwt, SensitiveDataPolicy.mask);
    }
    if (hasExact('AKIA') || hasExact('ASIA')) {
      safe = safe.replaceAll(_awsKey, SensitiveDataPolicy.mask);
    }
    if (has('gh') || has('github_pat_') || has('xox')) {
      safe = safe.replaceAll(_providerToken, SensitiveDataPolicy.mask);
    }
    if (hasExact('://')) {
      safe = safe.replaceAllMapped(
        _urlUserInfo,
        (Match m) => '${m[1]}${SensitiveDataPolicy.mask}@',
      );
    }
    if (secretName && (hasExact('?') || hasExact('&'))) {
      safe = safe.replaceAllMapped(
        _querySecret,
        (Match m) => '${m[1]}${SensitiveDataPolicy.mask}',
      );
    }
    if (secretName || has('cookie')) {
      safe = safe.replaceAllMapped(
        _assignment,
        (Match m) => '${m[1]}${SensitiveDataPolicy.mask}',
      );
    }
    safe = safe.replaceAllMapped(_base64, (Match match) {
      final String candidate = match.group(0)!;
      return SensitiveDataPolicy.protects(
            utilityId: 'base64',
            values: <String>[candidate],
          )
          ? SensitiveDataPolicy.mask
          : candidate;
    });
    if (!hasExact('%')) return safe;
    return safe.replaceAllMapped(_percentEncoded, (Match match) {
      final String candidate = match.group(0)!;
      return SensitiveDataPolicy.protects(
            utilityId: 'url',
            values: <String>[candidate],
          )
          ? SensitiveDataPolicy.mask
          : candidate;
    });
  }

  static bool _continues(_SafeLine line, _EventBuilder current) {
    if (line.json) return false;
    final String trimmed = line.text.trimLeft();
    if (line.leadingTimestamp) return false;
    if (trimmed.isEmpty || line.text.length != trimmed.length) return true;
    if (trimmed.startsWith('at ') ||
        trimmed.startsWith('File "') ||
        _frameNumber.hasMatch(trimmed) ||
        (current.isStack &&
            (trimmed.startsWith('Suppressed:') ||
                trimmed.startsWith('Caused by:') ||
                trimmed.startsWith('note:') ||
                trimmed.startsWith('--- End of inner exception')))) {
      return true;
    }
    if (line.level != LogLevel.unknown) return false;
    final bool errorContext =
        current.level == LogLevel.error ||
        current.level == LogLevel.fatal ||
        current.isStack;
    return errorContext &&
        (trimmed.startsWith('Traceback (') ||
            trimmed.startsWith('stack backtrace:') ||
            _exceptionName.hasMatch(trimmed));
  }

  static LogLevel _detectLevel(String value) => _detectPrefix(value).level;

  /// The line's level, and whether it starts (with no leading whitespace)
  /// with a timestamp, from one set of prefix matches.
  static ({LogLevel level, bool leadingTimestamp}) _detectPrefix(String value) {
    String candidate = value.trimLeft();
    final Match? timestamp =
        _isoTimestamp.matchAsPrefix(candidate) ??
        _bracketTimestamp.matchAsPrefix(candidate) ??
        _epochTimestamp.matchAsPrefix(candidate);
    final bool leadingTimestamp =
        timestamp != null && candidate.length == value.length;
    if (timestamp != null) {
      candidate = candidate.substring(timestamp.end).trimLeft();
    }
    final String? level = _levelWord.firstMatch(candidate)?[1]?.toUpperCase();
    return (
      level: switch (level) {
        'TRACE' => LogLevel.trace,
        'DEBUG' => LogLevel.debug,
        'INFO' => LogLevel.info,
        'WARN' || 'WARNING' => LogLevel.warn,
        'ERROR' => LogLevel.error,
        'FATAL' => LogLevel.fatal,
        _ => LogLevel.unknown,
      },
      leadingTimestamp: leadingTimestamp,
    );
  }

  static LogLevel _jsonLevel(Object? value) {
    if (value is! Map) return LogLevel.unknown;
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      if (const <String>{
            'level',
            'severity',
            'loglevel',
          }.contains(entry.key.toString().toLowerCase()) &&
          entry.value != null) {
        return _detectLevel(entry.value.toString());
      }
    }
    return LogLevel.unknown;
  }

  static DateTime? _jsonTimestamp(Object? value) {
    if (value is! Map) return null;
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      if (const <String>{
            'timestamp',
            'time',
            'ts',
            '@timestamp',
          }.contains(entry.key.toString().toLowerCase()) &&
          entry.value != null) {
        return _detectTimestamp(entry.value.toString());
      }
    }
    return null;
  }

  static DateTime? _detectTimestamp(String value) {
    final String? iso =
        _isoTimestamp.firstMatch(value)?[1] ??
        _bracketTimestamp.firstMatch(value)?[1];
    if (iso != null) {
      String normalized = iso.replaceFirst(' ', 'T');
      final RegExpMatch? match = _isoFields.firstMatch(normalized);
      if (match == null) return null;
      final List<int> fields = <int>[
        for (int i = 1; i <= 6; i++) int.parse(match[i]!),
      ];
      final DateTime calendar = DateTime.utc(
        fields[0],
        fields[1],
        fields[2],
        fields[3],
        fields[4],
        fields[5],
      );
      if (calendar.year != fields[0] ||
          calendar.month != fields[1] ||
          calendar.day != fields[2] ||
          calendar.hour != fields[3] ||
          calendar.minute != fields[4] ||
          calendar.second != fields[5]) {
        return null;
      }
      if (!_zoneSuffix.hasMatch(normalized)) {
        normalized += 'Z';
      }
      final DateTime? parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed.toUtc();
    }
    final String? epoch = _epochLine.firstMatch(value.trim())?[1];
    if (epoch != null) {
      final int number = int.parse(epoch);
      return DateTime.fromMillisecondsSinceEpoch(
        epoch.length == 10 ? number * 1000 : number,
        isUtc: true,
      );
    }
    return null;
  }

  static String _stripAnsi(String input) {
    final StringBuffer output = StringBuffer();
    for (int i = 0; i < input.length;) {
      final int current = input.codeUnitAt(i);
      if (current == 0x9b) {
        i = _skipCsi(input, i + 1);
        continue;
      }
      if (current == 0x9d || current == 0x90) {
        i = _skipStringControl(input, i + 1, allowBell: current == 0x9d);
        continue;
      }
      if (current != 0x1b) {
        output.writeCharCode(current);
        i++;
        continue;
      }
      if (++i >= input.length) break;
      final int kind = input.codeUnitAt(i);
      if (kind == 0x0a || kind == 0x0d) continue;
      i++;
      if (kind == 0x5b) {
        i = _skipCsi(input, i);
      } else if (kind == 0x5d || kind == 0x50) {
        i = _skipStringControl(input, i, allowBell: kind == 0x5d);
      }
    }
    return output.toString();
  }

  static int _skipCsi(String input, int index) {
    while (index < input.length) {
      final int code = input.codeUnitAt(index);
      if (code == 0x0a || code == 0x0d) return index;
      index++;
      if (code >= 0x40 && code <= 0x7e) break;
    }
    return index;
  }

  static int _skipStringControl(
    String input,
    int index, {
    required bool allowBell,
  }) {
    while (index < input.length) {
      final int code = input.codeUnitAt(index);
      if (code == 0x0a || code == 0x0d) return index;
      index++;
      if ((allowBell && code == 0x07) || code == 0x9c) break;
      if (code == 0x1b &&
          index < input.length &&
          input.codeUnitAt(index) == 0x5c) {
        index++;
        break;
      }
    }
    return index;
  }
}

class _SafeLine {
  const _SafeLine(
    this.number,
    this.text, {
    this.json = false,
    this.level = LogLevel.unknown,
    this.leadingTimestamp = false,
    this.timestamp,
    this.endNumber,
    this.redacted = false,
  });

  final int number;
  final String text;
  final bool json;
  final LogLevel level;
  final bool leadingTimestamp;
  final DateTime? timestamp;
  final int? endNumber;
  final bool redacted;
}

class _EventBuilder {
  _EventBuilder(_SafeLine line)
    : startLine = line.number,
      endLine = line.endNumber ?? line.number,
      level = line.level,
      timestamp = line.timestamp,
      _isStack = _stackMarker(line.text),
      _lines = <String>[line.text];

  final int startLine;
  int endLine;
  LogLevel level;
  DateTime? timestamp;
  final List<String> _lines;
  bool _isStack;

  bool get isStack => _isStack;

  static bool _stackMarker(String line) {
    final String text = line.trimLeft();
    return text.startsWith('Traceback (') ||
        text.startsWith('stack backtrace:') ||
        text.startsWith('at ') ||
        text.startsWith('Unhandled exception:') ||
        text.startsWith('thread \'') ||
        LogStackInspector._exceptionLine.hasMatch(text);
  }

  void add(_SafeLine line) {
    endLine = line.endNumber ?? line.number;
    _lines.add(line.text);
    _isStack |= _stackMarker(line.text);
    if (level == LogLevel.unknown) level = line.level;
    timestamp ??= line.timestamp;
  }

  LogEvent build() {
    final String text = _lines.join('\n');
    return LogEvent._(
      startLine: startLine,
      endLine: endLine,
      level: level,
      timestampUtc: timestamp,
      text: text,
      artifacts: List<String>.unmodifiable(_artifacts(text)),
    );
  }

  static Iterable<String> _artifacts(String text) sync* {
    final String trimmed = text.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final Object? decoded = jsonDecode(trimmed);
        if (decoded is Map || decoded is List) {
          yield trimmed;
          return;
        }
      } on FormatException {
        // A bracketed log marker is not an artifact.
      }
    }
    final List<_ArtifactCandidate> candidates = <_ArtifactCandidate>[];
    for (final RegExp pattern in <RegExp>[
      LogStackInspector._url,
      LogStackInspector._uuid,
      LogStackInspector._hex,
      LogStackInspector._percentEncoded,
      LogStackInspector._base64,
    ]) {
      final Set<String> accepted = <String>{};
      for (final Match match in pattern.allMatches(text)) {
        final String value = match.group(0)!;
        if (value.length <= 4096 &&
            !value.contains(SensitiveDataPolicy.mask) &&
            !value.startsWith('[REDACTED') &&
            !value.startsWith('[TRUNCATED') &&
            _candidateAllowed(pattern, value) &&
            accepted.add(value)) {
          candidates.add(_ArtifactCandidate(match.start, value));
          if (accepted.length == 4) break;
        }
      }
    }
    candidates.sort(
      (_ArtifactCandidate a, _ArtifactCandidate b) =>
          a.offset.compareTo(b.offset),
    );
    final Set<String> seen = <String>{};
    for (final _ArtifactCandidate candidate in candidates) {
      if (seen.add(candidate.value)) yield candidate.value;
      if (seen.length == 4) break;
    }
  }

  static bool _candidateAllowed(RegExp pattern, String value) {
    if (pattern == LogStackInspector._base64) {
      String normalized = value.replaceAll('-', '+').replaceAll('_', '/');
      final int remainder = normalized.length % 4;
      if (remainder == 1) return false;
      if (remainder > 0) normalized += '=' * (4 - remainder);
      if (!EncodingParser.isBase64(normalized) ||
          SensitiveDataPolicy.protects(
            utilityId: 'base64',
            values: <String>[value],
          )) {
        return false;
      }
      try {
        final List<int> bytes = base64.decode(normalized);
        return bytes.isNotEmpty &&
            bytes.every(
              (int byte) =>
                  byte == 0x09 ||
                  byte == 0x0a ||
                  byte == 0x0d ||
                  (byte >= 0x20 && byte <= 0x7e),
            );
      } on FormatException {
        return false;
      }
    }
    if (pattern == LogStackInspector._percentEncoded) {
      return !SensitiveDataPolicy.protects(
        utilityId: 'url',
        values: <String>[value],
      );
    }
    return !SensitiveDataPolicy.protects(values: <String>[value]);
  }
}

class _ArtifactCandidate {
  const _ArtifactCandidate(this.offset, this.value);
  final int offset;
  final String value;
}

class _JsonBudget {
  int nodes = 0;
  bool redacted = false;
}
