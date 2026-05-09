import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/cron_nl_parser.dart';
import 'package:masquerade/utils/cron_parser.dart';

void main() {
  group('CronNlParser — macros', () {
    test('every minute → * * * * *', () {
      final CronParseResult r = CronNlParser.parse('every minute');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '* * * * *');
      expect(r.mode, CronParsedMode.naturalLanguage);
    });

    test('hourly → 0 * * * *', () {
      final CronParseResult r = CronNlParser.parse('hourly');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 * * * *');
      expect(r.schedule!.macro, '@hourly');
    });

    test('daily → 0 0 * * *', () {
      final CronParseResult r = CronNlParser.parse('daily');
      expect(r.schedule!.canonical, '0 0 * * *');
      expect(r.schedule!.macro, '@daily');
    });

    test('weekly → 0 0 * * 0', () {
      final CronParseResult r = CronNlParser.parse('weekly');
      expect(r.schedule!.canonical, '0 0 * * 0');
    });

    test('monthly → 0 0 1 * *', () {
      final CronParseResult r = CronNlParser.parse('monthly');
      expect(r.schedule!.canonical, '0 0 1 * *');
    });

    test('yearly → 0 0 1 1 *', () {
      final CronParseResult r = CronNlParser.parse('yearly');
      expect(r.schedule!.canonical, '0 0 1 1 *');
    });

    test('annually aliases yearly', () {
      final CronParseResult r = CronNlParser.parse('annually');
      expect(r.schedule!.canonical, '0 0 1 1 *');
    });
  });

  group('CronNlParser — every N units', () {
    test('every 15 minutes → */15 * * * *', () {
      final CronParseResult r = CronNlParser.parse('every 15 minutes');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '*/15 * * * *');
    });

    test('every 1 minute', () {
      final CronParseResult r = CronNlParser.parse('every 1 minute');
      expect(r.schedule!.canonical, '*/1 * * * *');
    });

    test('every 6 hours', () {
      final CronParseResult r = CronNlParser.parse('every 6 hours');
      expect(r.schedule!.canonical, '0 */6 * * *');
    });

    test('every 0 minutes rejected', () {
      final CronParseResult r = CronNlParser.parse('every 0 minutes');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('positive'));
    });

    test('every 60 minutes rejected', () {
      final CronParseResult r = CronNlParser.parse('every 60 minutes');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('1-59'));
    });
  });

  group('CronNlParser — every <weekday> at <time>', () {
    test('every monday at 9am → 0 9 * * 1', () {
      final CronParseResult r = CronNlParser.parse('every monday at 9am');
      expect(r.isSuccess, isTrue);
      expect(r.schedule!.canonical, '0 9 * * 1');
    });

    test('every friday at 5pm → 0 17 * * 5', () {
      final CronParseResult r = CronNlParser.parse('every friday at 5pm');
      expect(r.schedule!.canonical, '0 17 * * 5');
    });

    test('every weekday at 9am → 0 9 * * 1-5', () {
      final CronParseResult r = CronNlParser.parse('every weekday at 9am');
      expect(r.schedule!.canonical, '0 9 * * 1-5');
    });

    test('every weekend at midnight via 12am → 0 0 * * 0,6', () {
      final CronParseResult r = CronNlParser.parse('every weekend at 12am');
      expect(r.schedule!.canonical, '0 0 * * 0,6');
    });

    test('weekdays alone → 0 0 * * 1-5', () {
      final CronParseResult r = CronNlParser.parse('weekdays');
      expect(r.schedule!.canonical, '0 0 * * 1-5');
    });

    test('every monday with no time → 0 0 * * 1', () {
      final CronParseResult r = CronNlParser.parse('every monday');
      expect(r.schedule!.canonical, '0 0 * * 1');
    });

    test('every wednesday short form (wed)', () {
      final CronParseResult r = CronNlParser.parse('every wed at 9am');
      expect(r.schedule!.canonical, '0 9 * * 3');
    });
  });

  group('CronNlParser — at <time> on <days>', () {
    test('at 9am on weekdays → 0 9 * * 1-5', () {
      final CronParseResult r = CronNlParser.parse('at 9am on weekdays');
      expect(r.schedule!.canonical, '0 9 * * 1-5');
    });

    test('at 14:30 on monday → 30 14 * * 1', () {
      final CronParseResult r = CronNlParser.parse('at 14:30 on monday');
      expect(r.schedule!.canonical, '30 14 * * 1');
    });

    test('at 9am alone (no day) → 0 9 * * *', () {
      final CronParseResult r = CronNlParser.parse('at 9am');
      expect(r.schedule!.canonical, '0 9 * * *');
    });

    test('at 9:30 (24h, no am/pm) → 30 9 * * *', () {
      final CronParseResult r = CronNlParser.parse('at 9:30');
      expect(r.schedule!.canonical, '30 9 * * *');
    });

    test('at 9 (bare integer) is rejected', () {
      final CronParseResult r = CronNlParser.parse('at 9');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('time'));
    });

    test('at 12pm → 0 12 (noon)', () {
      final CronParseResult r = CronNlParser.parse('at 12pm');
      expect(r.schedule!.canonical, '0 12 * * *');
    });

    test('at 12am → 0 0 (midnight)', () {
      final CronParseResult r = CronNlParser.parse('at 12am');
      expect(r.schedule!.canonical, '0 0 * * *');
    });

    test('at 13pm rejected (out of 1-12 range)', () {
      final CronParseResult r = CronNlParser.parse('at 13pm');
      expect(r.isSuccess, isFalse);
    });

    test('on monday and friday', () {
      final CronParseResult r = CronNlParser.parse(
        'at 9am on monday and friday',
      );
      expect(r.schedule!.canonical, '0 9 * * 1,5');
    });

    test('on mon, wed, fri with commas', () {
      final CronParseResult r = CronNlParser.parse('at 9am on mon, wed, fri');
      expect(r.schedule!.canonical, '0 9 * * 1,3,5');
    });
  });

  group('CronNlParser — case insensitivity', () {
    test('uppercase EVERY MONDAY', () {
      final CronParseResult r = CronNlParser.parse('EVERY MONDAY AT 9AM');
      expect(r.schedule!.canonical, '0 9 * * 1');
    });

    test('mixed case', () {
      final CronParseResult r = CronNlParser.parse('Every Friday at 5PM');
      expect(r.schedule!.canonical, '0 17 * * 5');
    });
  });

  group('CronNlParser — rejection', () {
    test('empty input', () {
      final CronParseResult r = CronNlParser.parse('');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('Empty'));
    });

    test('every penguin (out-of-vocab)', () {
      final CronParseResult r = CronNlParser.parse('every penguin');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('Unsupported'));
    });

    test('non-grammar phrase', () {
      final CronParseResult r = CronNlParser.parse('penguins ride bicycles');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('Unsupported'));
    });

    test('at <invalid time>', () {
      final CronParseResult r = CronNlParser.parse('at sunrise');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('time'));
    });

    test('on <invalid day>', () {
      final CronParseResult r = CronNlParser.parse('at 9am on plumdays');
      expect(r.isSuccess, isFalse);
      expect(r.nlError, contains('day'));
    });
  });

  group('CronNlParser — round trip via canonical → description', () {
    test('every monday at 9am description', () {
      final CronParseResult r = CronNlParser.parse('every monday at 9am');
      expect(r.schedule!.description, 'At 09:00 on Monday.');
    });

    test('every weekday at 14:30 description', () {
      final CronParseResult r = CronNlParser.parse('every weekday at 14:30');
      expect(r.schedule!.description, 'At 14:30 on weekdays.');
    });
  });
}
