import 'cron_parser.dart';

/// Natural-language to cron parser. Closed compositional grammar:
///
/// ```
/// expr  := freq ( "at" time )? | "at" time ( "on" days )?
/// freq  := "every" ( unit | N units | weekday | "weekday" | "weekend" )
///        | macro
/// macro := "every minute" | "hourly" | "daily" | "weekly" | "monthly" | "yearly"
/// time  := H "am"|"pm" | H ":" MM ( "am"|"pm" )?
/// days  := weekday ( "," | "and" weekday )*
/// ```
///
/// Anything outside this grammar fails with a "unsupported phrase" error.
class CronNlParser {
  const CronNlParser._();

  static CronParseResult parse(String input) {
    final String norm = input.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (norm.isEmpty) {
      return const CronParseResult.failure(nlError: 'Empty input.');
    }

    final CronSchedule? macro = _tryMacro(norm);
    if (macro != null) {
      return CronParseResult.success(macro, CronParsedMode.naturalLanguage);
    }

    if (norm.startsWith('every ')) {
      return _parseEvery(norm.substring(6));
    }

    if (norm.startsWith('at ')) {
      return _parseAt(norm.substring(3));
    }

    final _DaySpec? day = _tryDaySpec(norm);
    if (day != null) {
      return CronParseResult.success(
        _build(minute: _zeroMinute(), hour: _zeroHour(), dayOfWeek: day.field),
        CronParsedMode.naturalLanguage,
      );
    }

    return CronParseResult.failure(
      nlError:
          'Unsupported phrase "$input". Try: "every monday at 9am", "at 14:30 on weekdays", "@daily", "every 15 minutes".',
    );
  }

  static CronSchedule? _tryMacro(String s) {
    switch (s) {
      case 'every minute':
        return _build();
      case 'hourly':
        return _build(minute: _zeroMinute());
      case 'daily':
        return _build(minute: _zeroMinute(), hour: _zeroHour());
      case 'weekly':
        return _build(
          minute: _zeroMinute(),
          hour: _zeroHour(),
          dayOfWeek: _singleField(0, 0, 6, 'day-of-week'),
        );
      case 'monthly':
        return _build(
          minute: _zeroMinute(),
          hour: _zeroHour(),
          dayOfMonth: _singleField(1, 1, 31, 'day-of-month'),
        );
      case 'yearly':
      case 'annually':
        return _build(
          minute: _zeroMinute(),
          hour: _zeroHour(),
          dayOfMonth: _singleField(1, 1, 31, 'day-of-month'),
          month: _singleField(1, 1, 12, 'month'),
        );
    }
    return null;
  }

  static CronParseResult _parseEvery(String rest) {
    final int atIdx = rest.indexOf(' at ');
    final String head = atIdx >= 0 ? rest.substring(0, atIdx) : rest;
    final String? timeStr = atIdx >= 0 ? rest.substring(atIdx + 4) : null;

    final Match? m = _everyNUnitsRe.firstMatch(head);
    if (m != null) {
      final int n = int.parse(m.group(1)!);
      if (n <= 0) {
        return CronParseResult.failure(
          nlError: 'Step must be positive, got $n.',
        );
      }
      final String unit = m.group(2)!;
      if (unit.startsWith('minute')) {
        if (n > 59) {
          return CronParseResult.failure(
            nlError: 'Minute step must be 1-59, got $n.',
          );
        }
        return _withTime(
          base: _build(minute: _stepField(n, 0, 59, 'minute')),
          timeStr: timeStr,
        );
      }
      if (n > 23) {
        return CronParseResult.failure(
          nlError: 'Hour step must be 1-23, got $n.',
        );
      }
      return _withTime(
        base: _build(minute: _zeroMinute(), hour: _stepField(n, 0, 23, 'hour')),
        timeStr: timeStr,
      );
    }

    switch (head) {
      case 'minute':
        return _withTime(base: _build(), timeStr: timeStr);
      case 'hour':
        return _withTime(
          base: _build(minute: _zeroMinute()),
          timeStr: timeStr,
        );
      case 'day':
        return _withTime(
          base: _build(minute: _zeroMinute(), hour: _zeroHour()),
          timeStr: timeStr,
        );
      case 'week':
        return _withTime(
          base: _build(
            minute: _zeroMinute(),
            hour: _zeroHour(),
            dayOfWeek: _singleField(0, 0, 6, 'day-of-week'),
          ),
          timeStr: timeStr,
        );
      case 'month':
        return _withTime(
          base: _build(
            minute: _zeroMinute(),
            hour: _zeroHour(),
            dayOfMonth: _singleField(1, 1, 31, 'day-of-month'),
          ),
          timeStr: timeStr,
        );
      case 'year':
        return _withTime(
          base: _build(
            minute: _zeroMinute(),
            hour: _zeroHour(),
            dayOfMonth: _singleField(1, 1, 31, 'day-of-month'),
            month: _singleField(1, 1, 12, 'month'),
          ),
          timeStr: timeStr,
        );
    }

    final _DaySpec? day = _tryDaySpec(head);
    if (day != null) {
      return _withTime(
        base: _build(
          minute: _zeroMinute(),
          hour: _zeroHour(),
          dayOfWeek: day.field,
        ),
        timeStr: timeStr,
      );
    }

    return CronParseResult.failure(
      nlError: 'Unsupported "every" clause: "$head".',
    );
  }

  static CronParseResult _parseAt(String rest) {
    final int onIdx = rest.indexOf(' on ');
    final String timeStr = onIdx >= 0 ? rest.substring(0, onIdx) : rest;
    final String? daysStr = onIdx >= 0 ? rest.substring(onIdx + 4) : null;

    final _Time? t = _parseTime(timeStr);
    if (t == null) {
      return CronParseResult.failure(
        nlError: 'Unrecognized time "$timeStr". Try "9am" or "14:30".',
      );
    }

    CronField dow = _starField(0, 6, 'day-of-week');
    if (daysStr != null) {
      final _DaySpec? day = _tryDaySpec(daysStr);
      if (day == null) {
        return CronParseResult.failure(
          nlError: 'Unrecognized day spec "$daysStr".',
        );
      }
      dow = day.field;
    }

    return CronParseResult.success(
      _build(
        minute: _singleField(t.minute, 0, 59, 'minute'),
        hour: _singleField(t.hour, 0, 23, 'hour'),
        dayOfWeek: dow,
      ),
      CronParsedMode.naturalLanguage,
    );
  }

  static CronParseResult _withTime({
    required CronSchedule base,
    required String? timeStr,
  }) {
    if (timeStr == null) {
      return CronParseResult.success(base, CronParsedMode.naturalLanguage);
    }
    final _Time? t = _parseTime(timeStr);
    if (t == null) {
      return CronParseResult.failure(
        nlError: 'Unrecognized time "$timeStr". Try "9am" or "14:30".',
      );
    }
    return CronParseResult.success(
      CronSchedule(
        minute: _singleField(t.minute, 0, 59, 'minute'),
        hour: _singleField(t.hour, 0, 23, 'hour'),
        dayOfMonth: base.dayOfMonth,
        month: base.month,
        dayOfWeek: base.dayOfWeek,
      ),
      CronParsedMode.naturalLanguage,
    );
  }

  /// Parses time strings: `9am`, `9:30am`, `09:30`, `14:30`. Rejects bare `9`
  /// (ambiguous am/pm) — the caller surfaces that as an error.
  static _Time? _parseTime(String raw) {
    final String s = raw.trim();
    final Match? cm = _timeColonRe.firstMatch(s);
    if (cm != null) {
      int h = int.parse(cm.group(1)!);
      final int m = int.parse(cm.group(2)!);
      final String? ap = cm.group(3);
      if (m < 0 || m > 59) return null;
      if (ap != null) {
        if (h < 1 || h > 12) return null;
        if (ap == 'pm' && h != 12) h += 12;
        if (ap == 'am' && h == 12) h = 0;
      }
      if (h < 0 || h > 23) return null;
      return _Time(h, m);
    }

    final Match? am = _timeAmPmRe.firstMatch(s);
    if (am != null) {
      int h = int.parse(am.group(1)!);
      final String ap = am.group(2)!;
      if (h < 1 || h > 12) return null;
      if (ap == 'pm' && h != 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return _Time(h, 0);
    }

    return null;
  }

  static _DaySpec? _tryDaySpec(String raw) {
    final String s = raw.trim();
    if (s == 'weekday' || s == 'weekdays') {
      return _DaySpec(
        CronField(
          atoms: const <CronAtom>[CronRange(1, 5)],
          min: 0,
          max: 6,
          label: 'day-of-week',
        ),
      );
    }
    if (s == 'weekend' || s == 'weekends') {
      return _DaySpec(
        CronField(
          atoms: const <CronAtom>[CronSingle(0), CronSingle(6)],
          min: 0,
          max: 6,
          label: 'day-of-week',
        ),
      );
    }

    final List<String> tokens = s
        .replaceAll(' and ', ',')
        .split(',')
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    final List<int> ints = <int>[];
    for (final String t in tokens) {
      final int? d = _weekdayMap[t];
      if (d == null) return null;
      ints.add(d);
    }
    final List<int> sorted = ints.toSet().toList()..sort();
    return _DaySpec(
      CronField(
        atoms: sorted.map((int d) => CronSingle(d)).toList(),
        min: 0,
        max: 6,
        label: 'day-of-week',
      ),
    );
  }

  static final RegExp _everyNUnitsRe = RegExp(
    r'^(\d+)\s+(minute|minutes|hour|hours)$',
  );
  static final RegExp _timeColonRe = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$');
  static final RegExp _timeAmPmRe = RegExp(r'^(\d{1,2})\s*(am|pm)$');

  static const Map<String, int> _weekdayMap = <String, int>{
    'sun': 0,
    'sunday': 0,
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'wed': 3,
    'weds': 3,
    'wednesday': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
  };

  static CronSchedule _build({
    CronField? minute,
    CronField? hour,
    CronField? dayOfMonth,
    CronField? month,
    CronField? dayOfWeek,
  }) => CronSchedule(
    minute: minute ?? _starField(0, 59, 'minute'),
    hour: hour ?? _starField(0, 23, 'hour'),
    dayOfMonth: dayOfMonth ?? _starField(1, 31, 'day-of-month'),
    month: month ?? _starField(1, 12, 'month'),
    dayOfWeek: dayOfWeek ?? _starField(0, 6, 'day-of-week'),
  );

  static CronField _starField(int min, int max, String label) => CronField(
    atoms: const <CronAtom>[CronStar()],
    min: min,
    max: max,
    label: label,
  );

  static CronField _singleField(int v, int min, int max, String label) =>
      CronField(
        atoms: <CronAtom>[CronSingle(v)],
        min: min,
        max: max,
        label: label,
      );

  static CronField _stepField(int step, int min, int max, String label) =>
      CronField(
        atoms: <CronAtom>[CronStep(const CronStar(), step)],
        min: min,
        max: max,
        label: label,
      );

  static CronField _zeroMinute() => _singleField(0, 0, 59, 'minute');
  static CronField _zeroHour() => _singleField(0, 0, 23, 'hour');
}

class _Time {
  const _Time(this.hour, this.minute);
  final int hour;
  final int minute;
}

class _DaySpec {
  const _DaySpec(this.field);
  final CronField field;
}
