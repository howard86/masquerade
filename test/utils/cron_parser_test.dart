import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/cron_parser.dart';

void main() {
  group('CronParser.parseSyntax — macros', () {
    test('@hourly expands to 0 * * * *', () {
      final CronParseResult r = CronParser.parseSyntax('@hourly');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 * * * *');
      expect(r.schedule!.macro, '@hourly');
    });

    test('@daily expands to 0 0 * * *', () {
      final CronParseResult r = CronParser.parseSyntax('@daily');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 0 * * *');
      expect(r.schedule!.macro, '@daily');
    });

    test('@midnight aliases @daily', () {
      final CronParseResult r = CronParser.parseSyntax('@midnight');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 0 * * *');
      expect(r.schedule!.macro, '@daily');
    });

    test('@weekly canonical', () {
      final CronParseResult r = CronParser.parseSyntax('@weekly');
      expect(r.schedule!.canonical, '0 0 * * 0');
      expect(r.schedule!.macro, '@weekly');
    });

    test('@monthly canonical', () {
      final CronParseResult r = CronParser.parseSyntax('@monthly');
      expect(r.schedule!.canonical, '0 0 1 * *');
      expect(r.schedule!.macro, '@monthly');
    });

    test('@yearly canonical', () {
      final CronParseResult r = CronParser.parseSyntax('@yearly');
      expect(r.schedule!.canonical, '0 0 1 1 *');
      expect(r.schedule!.macro, '@yearly');
    });

    test('@annually aliases @yearly', () {
      final CronParseResult r = CronParser.parseSyntax('@annually');
      expect(r.schedule!.canonical, '0 0 1 1 *');
      expect(r.schedule!.macro, '@yearly');
    });

    test('@reboot is rejected with named error', () {
      final CronParseResult r = CronParser.parseSyntax('@reboot');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Unknown macro'));
    });

    test('unknown macro is rejected', () {
      final CronParseResult r = CronParser.parseSyntax('@bananas');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Unknown macro'));
    });
  });

  group('CronParser.parseSyntax — 5-field basic', () {
    test('all stars matches every minute', () {
      final CronParseResult r = CronParser.parseSyntax('* * * * *');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '* * * * *');
      expect(r.schedule!.macro, isNull);
    });

    test('singleton values render as-is', () {
      final CronParseResult r = CronParser.parseSyntax('30 14 1 6 1');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '30 14 1 6 1');
    });

    test('range parses', () {
      final CronParseResult r = CronParser.parseSyntax('0 9 * * 1-5');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 9 * * 1-5');
      expect(r.schedule!.dayOfWeek.values, <int>{1, 2, 3, 4, 5});
    });

    test('list parses', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 * * 0,3,5');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.dayOfWeek.values, <int>{0, 3, 5});
    });

    test('star step parses */15 minute', () {
      final CronParseResult r = CronParser.parseSyntax('*/15 * * * *');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '*/15 * * * *');
      expect(r.schedule!.minute.values, <int>{0, 15, 30, 45});
    });

    test('range step parses 1-30/5', () {
      final CronParseResult r = CronParser.parseSyntax('1-30/5 * * * *');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.minute.values, <int>{1, 6, 11, 16, 21, 26});
    });

    test('start/step shorthand 5/15 expands to range', () {
      final CronParseResult r = CronParser.parseSyntax('5/15 * * * *');
      expect(r.isSuccess, isTrue);
      // 5/15 → 5-59/15 → 5, 20, 35, 50
      expect(r.schedule!.minute.values, <int>{5, 20, 35, 50});
    });
  });

  group('CronParser.parseSyntax — named values', () {
    test('weekday names lowercase', () {
      final CronParseResult r = CronParser.parseSyntax('0 9 * * mon');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.dayOfWeek.values, <int>{1});
    });

    test('weekday names uppercase', () {
      final CronParseResult r = CronParser.parseSyntax('0 9 * * MON');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.dayOfWeek.values, <int>{1});
    });

    test('weekday range MON-FRI', () {
      final CronParseResult r = CronParser.parseSyntax('0 9 * * MON-FRI');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.dayOfWeek.values, <int>{1, 2, 3, 4, 5});
    });

    test('month names', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 1 JAN *');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.month.values, <int>{1});
    });

    test('Sunday-7 aliases Sunday-0', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 * * 7');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.dayOfWeek.values, <int>{0});
    });
  });

  group('CronParser.parseSyntax — rejection', () {
    test('empty input rejected', () {
      final CronParseResult r = CronParser.parseSyntax('');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Empty'));
    });

    test('6-field rejected with named error', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 9 * * 1');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('6-field'));
    });

    test('7-field rejected', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 9 * * 1 2025');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('7-field'));
    });

    test('Quartz L rejected', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 L * *');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Quartz'));
    });

    test('Quartz # rejected', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 * * 1#3');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Quartz'));
    });

    test('Quartz ? rejected', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 ? * MON');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Quartz'));
    });

    test('out-of-range minute rejected', () {
      final CronParseResult r = CronParser.parseSyntax('60 * * * *');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('out of range'));
    });

    test('out-of-range hour rejected', () {
      final CronParseResult r = CronParser.parseSyntax('* 24 * * *');
      expect(r.isSuccess, isFalse);
    });

    test('out-of-range day-of-month rejected', () {
      final CronParseResult r = CronParser.parseSyntax('* * 32 * *');
      expect(r.isSuccess, isFalse);
    });

    test('out-of-range month rejected', () {
      final CronParseResult r = CronParser.parseSyntax('* * * 13 *');
      expect(r.isSuccess, isFalse);
    });

    test('zero step rejected', () {
      final CronParseResult r = CronParser.parseSyntax('*/0 * * * *');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('step'));
    });

    test('reversed range rejected', () {
      final CronParseResult r = CronParser.parseSyntax('5-1 * * * *');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('range'));
    });

    test('garbage input rejected', () {
      final CronParseResult r = CronParser.parseSyntax('not even close');
      expect(r.isSuccess, isFalse);
    });

    test('three fields rejected', () {
      final CronParseResult r = CronParser.parseSyntax('0 0 *');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, contains('Expected 5'));
    });
  });

  group('CronSchedule.nextRuns — basic', () {
    test('@hourly fires every hour at :00', () {
      final CronSchedule s = CronParser.parseSyntax('@hourly').schedule!;
      final DateTime from = DateTime(2026, 5, 8, 14, 30);
      final List<DateTime> runs = s.nextRuns(from, count: 3).toList();
      expect(runs, <DateTime>[
        DateTime(2026, 5, 8, 15, 0),
        DateTime(2026, 5, 8, 16, 0),
        DateTime(2026, 5, 8, 17, 0),
      ]);
    });

    test('@daily fires at midnight', () {
      final CronSchedule s = CronParser.parseSyntax('@daily').schedule!;
      final DateTime from = DateTime(2026, 5, 8, 14, 30);
      final List<DateTime> runs = s.nextRuns(from, count: 2).toList();
      expect(runs, <DateTime>[
        DateTime(2026, 5, 9, 0, 0),
        DateTime(2026, 5, 10, 0, 0),
      ]);
    });

    test('every weekday at 9am', () {
      // 2026-05-08 is a Friday.
      final CronSchedule s = CronParser.parseSyntax('0 9 * * 1-5').schedule!;
      final DateTime from = DateTime(2026, 5, 8, 12, 0);
      final List<DateTime> runs = s.nextRuns(from, count: 3).toList();
      // Next: Mon 5/11, Tue 5/12, Wed 5/13.
      expect(runs, <DateTime>[
        DateTime(2026, 5, 11, 9, 0),
        DateTime(2026, 5, 12, 9, 0),
        DateTime(2026, 5, 13, 9, 0),
      ]);
    });

    test('every 15 minutes', () {
      final CronSchedule s = CronParser.parseSyntax('*/15 * * * *').schedule!;
      final DateTime from = DateTime(2026, 5, 8, 14, 7);
      final List<DateTime> runs = s.nextRuns(from, count: 3).toList();
      expect(runs, <DateTime>[
        DateTime(2026, 5, 8, 14, 15),
        DateTime(2026, 5, 8, 14, 30),
        DateTime(2026, 5, 8, 14, 45),
      ]);
    });
  });

  group('CronSchedule.nextRuns — DOM/DOW OR semantics', () {
    test('DOM=1 OR DOW=Mon — both fire', () {
      // 0 0 1 * 1 → midnight on the 1st OR any Monday.
      final CronSchedule s = CronParser.parseSyntax('0 0 1 * 1').schedule!;
      // May 2026: 1st = Friday. First match after 5/1 noon is Mon 5/4 (DOW),
      // then Mon 5/11, Mon 5/18, Mon 5/25, then Jun 1 (Monday — both fire).
      final DateTime from = DateTime(2026, 5, 1, 12, 0);
      final List<DateTime> runs = s.nextRuns(from, count: 5).toList();
      expect(runs, <DateTime>[
        DateTime(2026, 5, 4, 0, 0),
        DateTime(2026, 5, 11, 0, 0),
        DateTime(2026, 5, 18, 0, 0),
        DateTime(2026, 5, 25, 0, 0),
        DateTime(2026, 6, 1, 0, 0),
      ]);
    });

    test('DOM=15 only (DOW=*) — fires on the 15th', () {
      final CronSchedule s = CronParser.parseSyntax('0 0 15 * *').schedule!;
      final DateTime from = DateTime(2026, 5, 1);
      final List<DateTime> runs = s.nextRuns(from, count: 2).toList();
      expect(runs, <DateTime>[DateTime(2026, 5, 15), DateTime(2026, 6, 15)]);
    });
  });

  group('CronSchedule.nextRuns — impossible schedules', () {
    test('Feb 30 yields no runs', () {
      final CronSchedule s = CronParser.parseSyntax('0 0 30 2 *').schedule!;
      final DateTime from = DateTime(2026, 1, 1);
      final List<DateTime> runs = s.nextRuns(from, count: 5).toList();
      expect(runs, isEmpty);
    });
  });

  group('CronSchedule.description', () {
    test('@daily reads as midnight every day', () {
      final CronSchedule s = CronParser.parseSyntax('@daily').schedule!;
      expect(s.description, 'At 00:00 every day.');
    });

    test('every weekday at 9am', () {
      final CronSchedule s = CronParser.parseSyntax('0 9 * * 1-5').schedule!;
      expect(s.description, 'At 09:00 on weekdays.');
    });

    test('weekend is recognized', () {
      final CronSchedule s = CronParser.parseSyntax('0 9 * * 0,6').schedule!;
      expect(s.description, 'At 09:00 on weekends.');
    });

    test('every 15 minutes', () {
      final CronSchedule s = CronParser.parseSyntax('*/15 * * * *').schedule!;
      expect(s.description, contains('Every 15 minutes'));
    });

    test('single weekday named', () {
      final CronSchedule s = CronParser.parseSyntax('30 14 * * 3').schedule!;
      expect(s.description, contains('14:30'));
      expect(s.description, contains('Wednesday'));
    });

    test('DOM and DOW both restricted shows OR', () {
      final CronSchedule s = CronParser.parseSyntax('0 0 1 * 1').schedule!;
      expect(s.description, contains('or'));
    });
  });

  group('CronParser.parse dispatcher', () {
    test('cron syntax goes through cron mode', () {
      final CronParseResult r = CronParser.parse('@daily');
      expect(r.isSuccess, isTrue);
      expect(r.mode, CronParsedMode.cron);
    });

    test('NL phrase goes through naturalLanguage mode', () {
      final CronParseResult r = CronParser.parse('every monday at 9am');
      expect(r.isSuccess, isTrue);
      expect(r.mode, CronParsedMode.naturalLanguage);
    });

    test('garbage returns both errors populated', () {
      final CronParseResult r = CronParser.parse('penguins ride bicycles');
      expect(r.isSuccess, isFalse);
      expect(r.cronError, isNotNull);
      expect(r.nlError, isNotNull);
    });
  });
}
