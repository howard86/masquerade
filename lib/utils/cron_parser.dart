import 'cron_nl_parser.dart';

/// Cron schedule parser — POSIX 5-field syntax with macro support.
///
/// Accepts: minute hour day-of-month month day-of-week, plus the macros
/// `@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly` (alias `@annually`).
/// Field characters: `*`, `,`, `-`, `/`, named DOW/MON (case-insensitive).
/// Rejects Quartz extensions (`L`, `W`, `#`, `?`), 6/7-field variants, and
/// `@reboot`.

/// One element inside a comma-joined cron field. Sealed union: [CronStar],
/// [CronSingle], [CronRange], [CronStep].
sealed class CronAtom {
  const CronAtom();

  /// Yields every concrete int this atom represents within `[min, max]`.
  Iterable<int> expand(int min, int max);

  String render();
}

class CronStar extends CronAtom {
  const CronStar();

  @override
  Iterable<int> expand(int min, int max) sync* {
    for (int i = min; i <= max; i++) {
      yield i;
    }
  }

  @override
  String render() => '*';
}

class CronSingle extends CronAtom {
  const CronSingle(this.value);
  final int value;

  @override
  Iterable<int> expand(int min, int max) =>
      value >= min && value <= max ? <int>[value] : const <int>[];

  @override
  String render() => '$value';
}

class CronRange extends CronAtom {
  const CronRange(this.from, this.to);
  final int from;
  final int to;

  @override
  Iterable<int> expand(int min, int max) sync* {
    final int lo = from < min ? min : from;
    final int hi = to > max ? max : to;
    for (int i = lo; i <= hi; i++) {
      yield i;
    }
  }

  @override
  String render() => '$from-$to';
}

/// `*/N` → `CronStep(CronStar(), N)`. `5-30/2` → `CronStep(CronRange(5, 30), 2)`.
/// `5/15` (start-step shorthand) is canonicalized to
/// `CronStep(CronRange(5, max), 15)` at parse time.
class CronStep extends CronAtom {
  const CronStep(this.base, this.step);
  final CronAtom base;
  final int step;

  @override
  Iterable<int> expand(int min, int max) sync* {
    final List<int> baseValues = base.expand(min, max).toList();
    if (baseValues.isEmpty) return;
    final int start = baseValues.first;
    for (final int v in baseValues) {
      if ((v - start) % step == 0) yield v;
    }
  }

  @override
  String render() {
    if (base is CronStar) return '*/$step';
    return '${base.render()}/$step';
  }
}

/// One cron field — a non-empty list of atoms joined with commas. The
/// constructor pre-expands the matching set so `matches` is O(1).
class CronField {
  CronField({
    required this.atoms,
    required this.min,
    required this.max,
    required this.label,
  }) : assert(atoms.isNotEmpty),
       values = _expandAtoms(atoms, min, max);

  final List<CronAtom> atoms;
  final int min;
  final int max;
  final String label;
  final Set<int> values;

  static Set<int> _expandAtoms(List<CronAtom> atoms, int min, int max) {
    final Set<int> out = <int>{};
    for (final CronAtom a in atoms) {
      out.addAll(a.expand(min, max));
    }
    return out;
  }

  bool get isStar => atoms.length == 1 && atoms.first is CronStar;

  bool matches(int v) => values.contains(v);

  String render() => atoms.map((CronAtom a) => a.render()).join(',');

  /// Sorted list of every value this field matches.
  List<int> get sortedValues => values.toList()..sort();
}

/// Final parsed schedule. Fields are stored as [CronField]s; canonical and
/// macro are derived once at construction.
class CronSchedule {
  CronSchedule({
    required this.minute,
    required this.hour,
    required this.dayOfMonth,
    required this.month,
    required this.dayOfWeek,
  }) : canonical = _canonicalOf(minute, hour, dayOfMonth, month, dayOfWeek),
       macro = _macroOf(minute, hour, dayOfMonth, month, dayOfWeek);

  final CronField minute;
  final CronField hour;
  final CronField dayOfMonth;
  final CronField month;
  final CronField dayOfWeek;

  /// Canonical 5-field rendering, e.g. `0 9 * * 1`.
  final String canonical;

  /// Equivalent macro keyword if this schedule structurally matches one
  /// (`@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`); else null.
  final String? macro;

  late final String description = CronDescription.of(this);

  static String _canonicalOf(
    CronField m,
    CronField h,
    CronField dom,
    CronField mon,
    CronField dow,
  ) =>
      '${m.render()} ${h.render()} ${dom.render()} ${mon.render()} ${dow.render()}';

  static String? _macroOf(
    CronField m,
    CronField h,
    CronField dom,
    CronField mon,
    CronField dow,
  ) {
    bool eq(CronField f, int v) =>
        !f.isStar && f.values.length == 1 && f.values.contains(v);
    final bool minZero = eq(m, 0);
    final bool hourZero = eq(h, 0);
    final bool domOne = eq(dom, 1);
    final bool monOne = eq(mon, 1);
    final bool dowZero = eq(dow, 0);

    if (minZero && h.isStar && dom.isStar && mon.isStar && dow.isStar) {
      return '@hourly';
    }
    if (minZero && hourZero && dom.isStar && mon.isStar && dow.isStar) {
      return '@daily';
    }
    if (minZero && hourZero && dom.isStar && mon.isStar && dowZero) {
      return '@weekly';
    }
    if (minZero && hourZero && domOne && mon.isStar && dow.isStar) {
      return '@monthly';
    }
    if (minZero && hourZero && domOne && monOne && dow.isStar) {
      return '@yearly';
    }
    return null;
  }

  /// Yields the next [count] DateTime instants this schedule fires at strictly
  /// after [from]. Empty when the schedule is structurally impossible (e.g.
  /// `0 0 30 2 *`). Bounded by an 8-year forward search.
  ///
  /// Implements POSIX/Vixie cron's day-of-month + day-of-week OR semantics:
  /// when both fields are restricted, a day matches if it satisfies _either_.
  Iterable<DateTime> nextRuns(DateTime from, {int count = 5}) sync* {
    if (count <= 0) return;
    final List<int> minutes = minute.sortedValues;
    final List<int> hours = hour.sortedValues;
    final List<int> months = month.sortedValues;
    if (minutes.isEmpty || hours.isEmpty || months.isEmpty) return;

    int yielded = 0;
    final int maxYear = from.year + 8;

    for (int year = from.year; year <= maxYear; year++) {
      for (final int mon in months) {
        if (year == from.year && mon < from.month) continue;
        final int lastDay = DateTime(year, mon + 1, 0).day;

        for (int day = 1; day <= lastDay; day++) {
          if (year == from.year && mon == from.month && day < from.day) {
            continue;
          }
          if (!_dayMatches(year, mon, day)) continue;

          for (final int h in hours) {
            for (final int m in minutes) {
              final DateTime candidate = DateTime(year, mon, day, h, m);
              if (!candidate.isAfter(from)) continue;
              yield candidate;
              yielded++;
              if (yielded >= count) return;
            }
          }
        }
      }
    }
  }

  bool _dayMatches(int year, int mon, int day) {
    final bool domStar = dayOfMonth.isStar;
    final bool dowStar = dayOfWeek.isStar;
    final int dowVal = DateTime(year, mon, day).weekday % 7; // 0=Sun..6=Sat
    if (domStar && dowStar) return true;
    if (!domStar && !dowStar) {
      return dayOfMonth.matches(day) || dayOfWeek.matches(dowVal);
    }
    if (!domStar) return dayOfMonth.matches(day);
    return dayOfWeek.matches(dowVal);
  }
}

enum CronParsedMode { cron, naturalLanguage }

/// Carries either a parsed [schedule] (with [mode]) or a structured failure
/// describing what each parser tried.
class CronParseResult {
  const CronParseResult.success(CronSchedule this.schedule, this.mode)
    : cronError = null,
      nlError = null;

  const CronParseResult.failure({this.cronError, this.nlError})
    : schedule = null,
      mode = null;

  final CronSchedule? schedule;
  final CronParsedMode? mode;
  final String? cronError;
  final String? nlError;

  bool get isSuccess => schedule != null;
}

/// Top-level cron parser. [parse] tries syntax first then natural language;
/// [parseSyntax] is the strict 5-field/macro path used by detection.
class CronParser {
  const CronParser._();

  static final RegExp _whitespaceRe = RegExp(r'\s+');
  static final RegExp _quartzDayRe = RegExp(r'^(L|W|\d+L|\d+W|L\d+|W\d+)$');

  static CronParseResult parse(String input) {
    final CronParseResult syntax = parseSyntax(input);
    if (syntax.isSuccess) return syntax;
    final CronParseResult nl = CronNlParser.parse(input);
    if (nl.isSuccess) return nl;
    return CronParseResult.failure(
      cronError: syntax.cronError,
      nlError: nl.nlError,
    );
  }

  static CronParseResult parseSyntax(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const CronParseResult.failure(cronError: 'Empty input.');
    }

    if (trimmed.startsWith('@')) {
      final String? expanded = _macroExpand(trimmed.toLowerCase());
      if (expanded == null) {
        return CronParseResult.failure(
          cronError:
              'Unknown macro: $trimmed. '
              'Supported: @hourly, @daily, @weekly, @monthly, @yearly.',
        );
      }
      return _parseTokens(expanded.split(' '), 'macro');
    }

    final List<String> tokens = trimmed.split(_whitespaceRe);

    // `L`/`W` overlap with weekday/month letters (`Wed`, `Friday`, `JaN`) so
    // they're caught by per-field value resolution rather than a global scan.
    if (trimmed.contains('?') || trimmed.contains('#')) {
      return const CronParseResult.failure(
        cronError:
            'Quartz extensions (L, W, #, ?) are not supported. POSIX 5-field cron only.',
      );
    }
    if (tokens.length == 5) {
      if (_quartzDayRe.hasMatch(tokens[2]) ||
          _quartzDayRe.hasMatch(tokens[4])) {
        return const CronParseResult.failure(
          cronError:
              'Quartz extensions (L, W, #, ?) are not supported. POSIX 5-field cron only.',
        );
      }
    }
    if (tokens.length == 6 || tokens.length == 7) {
      return CronParseResult.failure(
        cronError:
            '${tokens.length}-field cron not supported (POSIX 5-field only).',
      );
    }
    if (tokens.length != 5) {
      return CronParseResult.failure(
        cronError:
            'Expected 5 fields (minute hour day-of-month month day-of-week), got ${tokens.length}.',
      );
    }
    return _parseTokens(tokens, '5-field');
  }

  static CronParseResult _parseTokens(List<String> tokens, String origin) {
    try {
      final CronField minute = _parseField(
        tokens[0],
        min: 0,
        max: 59,
        label: 'minute',
      );
      final CronField hour = _parseField(
        tokens[1],
        min: 0,
        max: 23,
        label: 'hour',
      );
      final CronField dayOfMonth = _parseField(
        tokens[2],
        min: 1,
        max: 31,
        label: 'day-of-month',
      );
      final CronField month = _parseField(
        tokens[3],
        min: 1,
        max: 12,
        label: 'month',
        names: _monthNames,
      );
      final CronField dayOfWeek = _parseField(
        tokens[4],
        min: 0,
        max: 6,
        label: 'day-of-week',
        names: _dayNames,
        // 7 is a POSIX-accepted alias for 0 (Sunday); normalize on parse.
        aliasMap: const <int, int>{7: 0},
      );
      return CronParseResult.success(
        CronSchedule(
          minute: minute,
          hour: hour,
          dayOfMonth: dayOfMonth,
          month: month,
          dayOfWeek: dayOfWeek,
        ),
        CronParsedMode.cron,
      );
    } on _CronParseException catch (e) {
      return CronParseResult.failure(cronError: '[$origin] ${e.message}');
    }
  }

  static String? _macroExpand(String macro) => switch (macro) {
    '@hourly' => '0 * * * *',
    '@daily' || '@midnight' => '0 0 * * *',
    '@weekly' => '0 0 * * 0',
    '@monthly' => '0 0 1 * *',
    '@yearly' || '@annually' => '0 0 1 1 *',
    _ => null,
  };

  static CronField _parseField(
    String raw, {
    required int min,
    required int max,
    required String label,
    Map<String, int>? names,
    Map<int, int>? aliasMap,
  }) {
    if (raw.isEmpty) {
      throw _CronParseException('Empty $label field.');
    }
    final List<CronAtom> atoms = <CronAtom>[];
    for (final String part in raw.split(',')) {
      atoms.add(
        _parseAtom(
          part,
          min: min,
          max: max,
          label: label,
          names: names,
          aliasMap: aliasMap,
        ),
      );
    }
    return CronField(atoms: atoms, min: min, max: max, label: label);
  }

  static CronAtom _parseAtom(
    String raw, {
    required int min,
    required int max,
    required String label,
    Map<String, int>? names,
    Map<int, int>? aliasMap,
  }) {
    if (raw.isEmpty) {
      throw _CronParseException('Empty atom in $label field.');
    }

    String body = raw;
    int? step;
    final int slash = raw.indexOf('/');
    if (slash >= 0) {
      body = raw.substring(0, slash);
      final String stepStr = raw.substring(slash + 1);
      final int? s = int.tryParse(stepStr);
      if (s == null || s <= 0) {
        throw _CronParseException(
          'Invalid step "$stepStr" in $label (must be a positive integer).',
        );
      }
      step = s;
    }

    final CronAtom base = _parseBase(
      body,
      min: min,
      max: max,
      label: label,
      names: names,
      aliasMap: aliasMap,
    );

    if (step == null) return base;

    // POSIX shorthand: `5/15` is equivalent to `5-max/15`.
    if (base is CronSingle) {
      return CronStep(CronRange(base.value, max), step);
    }
    if (base is CronStar || base is CronRange) {
      return CronStep(base, step);
    }
    throw _CronParseException(
      'Step base must be *, single value, or range in $label.',
    );
  }

  static CronAtom _parseBase(
    String raw, {
    required int min,
    required int max,
    required String label,
    Map<String, int>? names,
    Map<int, int>? aliasMap,
  }) {
    if (raw == '*') return const CronStar();

    final int dash = raw.indexOf('-');
    if (dash > 0) {
      final String fromStr = raw.substring(0, dash);
      final String toStr = raw.substring(dash + 1);
      final int from = _resolveValue(fromStr, min, max, label, names, aliasMap);
      final int to = _resolveValue(toStr, min, max, label, names, aliasMap);
      if (from > to) {
        throw _CronParseException(
          'Invalid range "$raw" in $label (from > to).',
        );
      }
      return CronRange(from, to);
    }

    final int v = _resolveValue(raw, min, max, label, names, aliasMap);
    return CronSingle(v);
  }

  static int _resolveValue(
    String raw,
    int min,
    int max,
    String label,
    Map<String, int>? names,
    Map<int, int>? aliasMap,
  ) {
    int? v = int.tryParse(raw);
    if (v == null && names != null) {
      v = names[raw.toLowerCase()];
    }
    if (v == null) {
      throw _CronParseException('Invalid value "$raw" in $label.');
    }
    if (aliasMap != null && aliasMap.containsKey(v)) {
      v = aliasMap[v];
    }
    if (v! < min || v > max) {
      throw _CronParseException(
        'Value "$raw" out of range for $label ($min-$max).',
      );
    }
    return v;
  }

  static const Map<String, int> _monthNames = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static const Map<String, int> _dayNames = <String, int>{
    'sun': 0,
    'mon': 1,
    'tue': 2,
    'wed': 3,
    'thu': 4,
    'fri': 5,
    'sat': 6,
  };
}

class _CronParseException implements Exception {
  _CronParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Renders a human-readable description for a parsed [CronSchedule].
class CronDescription {
  const CronDescription._();

  static const List<String> _weekdayNames = <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<String> _monthNames = <String>[
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String of(CronSchedule s) {
    final String time = _timeClause(s.minute, s.hour);
    final String day = _dayClause(s.dayOfMonth, s.dayOfWeek);
    final String mon = _monthClause(s.month);

    final List<String> parts = <String>[time];
    if (day.isNotEmpty) parts.add(day);
    if (mon.isNotEmpty) parts.add(mon);
    final String body = parts.join(' ');
    return '${body[0].toUpperCase()}${body.substring(1)}.';
  }

  static String _timeClause(CronField minute, CronField hour) {
    final bool minuteIsSingle = minute.values.length == 1;
    final bool hourIsSingle = hour.values.length == 1;

    if (minuteIsSingle && hourIsSingle) {
      final int m = minute.sortedValues.first;
      final int h = hour.sortedValues.first;
      return 'at ${_pad(h)}:${_pad(m)}';
    }

    if (hour.isStar && minute.isStar) return 'every minute';

    final String mClause = _stepOrEveryClause(minute, 'minute');
    final String hClause = hour.isStar ? '' : _hourClause(hour);

    if (hClause.isEmpty) return mClause;
    return '$mClause $hClause';
  }

  static String _hourClause(CronField hour) {
    if (hour.values.length == 1) return 'past hour ${hour.sortedValues.first}';
    if (hour.atoms.length == 1 && hour.atoms.first is CronRange) {
      final CronRange r = hour.atoms.first as CronRange;
      return 'from hour ${r.from} through ${r.to}';
    }
    if (hour.atoms.length == 1 && hour.atoms.first is CronStep) {
      final CronStep st = hour.atoms.first as CronStep;
      return 'every ${st.step} hours';
    }
    return 'on hours ${hour.sortedValues.join(", ")}';
  }

  static String _stepOrEveryClause(CronField f, String unit) {
    if (f.atoms.length == 1) {
      final CronAtom a = f.atoms.first;
      if (a is CronStar) return 'every $unit';
      if (a is CronStep && a.base is CronStar) {
        return 'every ${a.step} ${unit}s';
      }
      if (a is CronRange) return 'every $unit from ${a.from} through ${a.to}';
      if (a is CronStep && a.base is CronRange) {
        final CronRange b = a.base as CronRange;
        return 'every ${a.step} ${unit}s from ${b.from} through ${b.to}';
      }
      if (a is CronSingle) return 'at $unit ${a.value}';
    }
    return 'at ${unit}s ${f.sortedValues.join(", ")}';
  }

  static String _dayClause(CronField dom, CronField dow) {
    final bool domStar = dom.isStar;
    final bool dowStar = dow.isStar;
    if (domStar && dowStar) return 'every day';

    final String domPart = domStar ? '' : _domPart(dom);
    final String dowPart = dowStar ? '' : _dowPart(dow);

    if (domPart.isNotEmpty && dowPart.isNotEmpty) {
      // Vixie OR semantics — surface this so users aren't surprised.
      return '$domPart or $dowPart';
    }
    return domPart.isNotEmpty ? domPart : dowPart;
  }

  static String _domPart(CronField dom) {
    if (dom.values.length == 1) {
      return 'on day ${dom.sortedValues.first} of the month';
    }
    if (dom.atoms.length == 1 && dom.atoms.first is CronRange) {
      final CronRange r = dom.atoms.first as CronRange;
      return 'on days ${r.from}-${r.to} of the month';
    }
    if (dom.atoms.length == 1 && dom.atoms.first is CronStep) {
      final CronStep st = dom.atoms.first as CronStep;
      return 'every ${st.step} days';
    }
    return 'on days ${dom.sortedValues.join(", ")} of the month';
  }

  static String _dowPart(CronField dow) {
    final List<int> sorted = dow.sortedValues;
    if (_listEquals(sorted, const <int>[1, 2, 3, 4, 5])) return 'on weekdays';
    if (_listEquals(sorted, const <int>[0, 6])) return 'on weekends';
    if (sorted.length == 1) return 'on ${_weekdayNames[sorted.first]}';
    final List<String> names = sorted.map((int d) => _weekdayNames[d]).toList();
    if (names.length == 2) return 'on ${names.join(' and ')}';
    return 'on ${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}';
  }

  static String _monthClause(CronField month) {
    if (month.isStar) return '';
    if (month.values.length == 1) {
      return 'in ${_monthNames[month.sortedValues.first]}';
    }
    if (month.atoms.length == 1 && month.atoms.first is CronRange) {
      final CronRange r = month.atoms.first as CronRange;
      return 'from ${_monthNames[r.from]} through ${_monthNames[r.to]}';
    }
    final List<String> names = month.sortedValues
        .map((int m) => _monthNames[m])
        .toList();
    return 'in ${names.join(', ')}';
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
