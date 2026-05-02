/// Enum representing different timestamp formats.
enum TimestampFormat {
  unixSeconds,
  unixMilliseconds,
  unixMicroseconds,
  unixNanoseconds,
  iso8601,
  keyword,
  unknown,
}

/// Result of timestamp parsing.
class TimestampParseResult {
  const TimestampParseResult({
    required this.timestamp,
    required this.format,
    this.isAmbiguous = false,
    this.isNaive = false,
    this.alternatives = const <TimestampParseResult>[],
  });

  final DateTime? timestamp;
  final TimestampFormat format;

  /// True when the input integer falls in the seconds/ms overlap range
  /// `[1e9, 1e12)` and could plausibly be either.
  final bool isAmbiguous;

  /// True when an ISO 8601 input lacked a `Z` or `±HH:MM` offset, so
  /// `DateTime.parse` interpreted it in the device's local time zone.
  final bool isNaive;

  /// Alternative interpretations populated when [isAmbiguous] is true.
  final List<TimestampParseResult> alternatives;

  bool get isSuccess => timestamp != null;
  bool get isUnknown => format == TimestampFormat.unknown;
}

/// Internal time-bucket unit for keyword resolution.
enum _KeywordUnit { second, minute, hour, day, week, month, year }

typedef _KeywordResolver = DateTime Function(DateTime now);

DateTime _truncate(DateTime now, _KeywordUnit unit) {
  switch (unit) {
    case _KeywordUnit.second:
      return DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );
    case _KeywordUnit.minute:
      return DateTime(now.year, now.month, now.day, now.hour, now.minute);
    case _KeywordUnit.hour:
      return DateTime(now.year, now.month, now.day, now.hour);
    case _KeywordUnit.day:
      return DateTime(now.year, now.month, now.day);
    case _KeywordUnit.week:
      // ISO week — Monday = start. weekday: 1=Mon..7=Sun.
      return DateTime(now.year, now.month, now.day - (now.weekday - 1));
    case _KeywordUnit.month:
      return DateTime(now.year, now.month, 1);
    case _KeywordUnit.year:
      return DateTime(now.year, 1, 1);
  }
}

DateTime _offset(DateTime base, _KeywordUnit unit, int delta) {
  switch (unit) {
    case _KeywordUnit.second:
      return base.add(Duration(seconds: delta));
    case _KeywordUnit.minute:
      return base.add(Duration(minutes: delta));
    case _KeywordUnit.hour:
      return base.add(Duration(hours: delta));
    case _KeywordUnit.day:
      return DateTime(base.year, base.month, base.day + delta);
    case _KeywordUnit.week:
      return DateTime(base.year, base.month, base.day + 7 * delta);
    case _KeywordUnit.month:
      return DateTime(base.year, base.month + delta, 1);
    case _KeywordUnit.year:
      return DateTime(base.year + delta, 1, 1);
  }
}

_KeywordResolver _bucket(_KeywordUnit unit, int delta) {
  return (DateTime now) => delta == 0
      ? _truncate(now, unit)
      : _offset(_truncate(now, unit), unit, delta);
}

final Map<String, _KeywordResolver> _keywords = <String, _KeywordResolver>{
  'now': (DateTime now) => now,
  'today': _bucket(_KeywordUnit.day, 0),
  'yesterday': _bucket(_KeywordUnit.day, -1),
  'tomorrow': _bucket(_KeywordUnit.day, 1),
  for (final _KeywordUnit u
      in _KeywordUnit.values) ...<String, _KeywordResolver>{
    'this ${u.name}': _bucket(u, 0),
    'last ${u.name}': _bucket(u, -1),
    'next ${u.name}': _bucket(u, 1),
  },
};

/// Ordered list of every supported keyword. Mirrors the [parseKeyword] map.
const List<String> kTimestampKeywords = <String>[
  'now',
  'today',
  'yesterday',
  'tomorrow',
  'last second',
  'this second',
  'next second',
  'last minute',
  'this minute',
  'next minute',
  'last hour',
  'this hour',
  'next hour',
  'last day',
  'this day',
  'next day',
  'last week',
  'this week',
  'next week',
  'last month',
  'this month',
  'next month',
  'last year',
  'this year',
  'next year',
];

/// Utility functions for parsing timestamps from various formats.
class TimestampParser {
  static final RegExp _isoWithTzRegExp = RegExp(r'(?:[Zz]|[+-]\d{2}:?\d{2})$');
  static final RegExp _digitsOnlyRegExp = RegExp(r'^-?\d+$');
  static final RegExp _whitespaceRegExp = RegExp(r'\s+');
  static final RegExp _dateOnlyRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses a timestamp from various input formats. Returns the [DateTime] if
  /// recognized, or `null` if no parser matches.
  ///
  /// Recognizes:
  /// - Unix seconds, milliseconds, microseconds, nanoseconds (by digit count)
  /// - ISO 8601 strings
  static DateTime? parseTimestamp(String input) {
    return parseAnyFormat(input).timestamp;
  }

  /// True if [input] is recognizable as any supported format.
  static bool isValidTimestamp(String input) => parseAnyFormat(input).isSuccess;

  /// Comprehensive parser. Tries keyword → numeric (s/ms/µs/ns by digit count)
  /// → ISO 8601, then returns unknown.
  ///
  /// [now] overrides the clock anchor used by keyword resolution. Defaults to
  /// `DateTime.now()` and exists primarily as a test seam.
  static TimestampParseResult parseAnyFormat(String input, {DateTime? now}) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return _unknown;

    final TimestampParseResult kw = parseKeyword(trimmed, now: now);
    if (kw.isSuccess) return kw;

    if (_digitsOnlyRegExp.hasMatch(trimmed)) return _parseNumeric(trimmed);

    return _tryIso(trimmed) ?? _unknown;
  }

  /// Parses [input] using the explicit [hint] format, ignoring auto-detection.
  ///
  /// Returns unknown for [TimestampFormat.unknown]. The [now] parameter is
  /// only consulted when [hint] is [TimestampFormat.keyword].
  static TimestampParseResult parseAs(
    String input,
    TimestampFormat hint, {
    DateTime? now,
  }) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty || hint == TimestampFormat.unknown) return _unknown;
    switch (hint) {
      case TimestampFormat.unixSeconds:
      case TimestampFormat.unixMilliseconds:
      case TimestampFormat.unixMicroseconds:
      case TimestampFormat.unixNanoseconds:
        return _asUnix(trimmed, hint);
      case TimestampFormat.iso8601:
        return _tryIso(trimmed) ?? _unknown;
      case TimestampFormat.keyword:
        return parseKeyword(trimmed, now: now);
      case TimestampFormat.unknown:
        return _unknown;
    }
  }

  /// Resolves a closed-set English keyword to an anchored [DateTime].
  ///
  /// Supported tokens (case-insensitive, whitespace-collapsed):
  /// `now`, `today`, `yesterday`, `tomorrow`, plus
  /// `<this|last|next> <second|minute|hour|day|week|month|year>`.
  ///
  /// Week start follows ISO convention (Monday).
  static TimestampParseResult parseKeyword(String input, {DateTime? now}) {
    final String key = input.trim().toLowerCase().replaceAll(
      _whitespaceRegExp,
      ' ',
    );
    final _KeywordResolver? resolver = _keywords[key];
    if (resolver == null) return _unknown;
    return TimestampParseResult(
      timestamp: resolver(now ?? DateTime.now()),
      format: TimestampFormat.keyword,
    );
  }

  static const TimestampParseResult _unknown = TimestampParseResult(
    timestamp: null,
    format: TimestampFormat.unknown,
  );

  static TimestampParseResult? _tryIso(String trimmed) {
    try {
      final DateTime parsed = DateTime.parse(trimmed);
      return TimestampParseResult(
        timestamp: parsed,
        format: TimestampFormat.iso8601,
        isNaive:
            !_isoWithTzRegExp.hasMatch(trimmed) &&
            !_dateOnlyRegExp.hasMatch(trimmed),
      );
    } catch (_) {
      return null;
    }
  }

  static TimestampParseResult _parseNumeric(String trimmed) {
    final int? n = int.tryParse(trimmed);
    if (n == null) return _unknown;
    final int absDigits = trimmed.length - (trimmed.startsWith('-') ? 1 : 0);
    if (absDigits <= 10) {
      final int absN = n.abs();
      final bool ambiguous = absN >= 1_000_000_000 && absN < 1_000_000_000_000;
      return TimestampParseResult(
        timestamp: DateTime.fromMillisecondsSinceEpoch(n * 1000),
        format: TimestampFormat.unixSeconds,
        isAmbiguous: ambiguous,
        alternatives: ambiguous
            ? <TimestampParseResult>[
                TimestampParseResult(
                  timestamp: DateTime.fromMillisecondsSinceEpoch(n),
                  format: TimestampFormat.unixMilliseconds,
                ),
              ]
            : const <TimestampParseResult>[],
      );
    }
    if (absDigits <= 13) return _unixFor(n, TimestampFormat.unixMilliseconds);
    if (absDigits <= 16) return _unixFor(n, TimestampFormat.unixMicroseconds);
    if (absDigits <= 19) return _unixFor(n, TimestampFormat.unixNanoseconds);
    return _unknown;
  }

  static TimestampParseResult _asUnix(String trimmed, TimestampFormat hint) {
    final int? n = int.tryParse(trimmed);
    if (n == null) return _unknown;
    return _unixFor(n, hint);
  }

  static TimestampParseResult _unixFor(int n, TimestampFormat hint) {
    final int micros = switch (hint) {
      TimestampFormat.unixSeconds => n * 1000000,
      TimestampFormat.unixMilliseconds => n * 1000,
      TimestampFormat.unixMicroseconds => n,
      TimestampFormat.unixNanoseconds => n ~/ 1000,
      _ => 0,
    };
    return TimestampParseResult(
      timestamp: DateTime.fromMicrosecondsSinceEpoch(micros),
      format: hint,
    );
  }
}
