import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/timestamp_parser.dart';

void main() {
  group('TimestampParser', () {
    group('parseTimestamp', () {
      test('returns null for empty input', () {
        expect(TimestampParser.parseTimestamp(''), isNull);
        expect(TimestampParser.parseTimestamp('   '), isNull);
      });

      test('parses Unix timestamp in seconds', () {
        const timestampSeconds = '1672531200';
        final result = TimestampParser.parseTimestamp(timestampSeconds);

        expect(result, isNotNull);
        expect(result!.toUtc().year, equals(2023));
        expect(result.toUtc().month, equals(1));
        expect(result.toUtc().day, equals(1));
      });

      test('parses Unix timestamp in milliseconds', () {
        const timestampMillis = '1672531200000';
        final result = TimestampParser.parseTimestamp(timestampMillis);

        expect(result, isNotNull);
        expect(result!.toUtc().year, equals(2023));
        expect(result.toUtc().month, equals(1));
        expect(result.toUtc().day, equals(1));
      });

      test('parses JavaScript Date.now() timestamp', () {
        const jsTimestamp = '1759493075163';
        final result = TimestampParser.parseTimestamp(jsTimestamp);

        expect(result, isNotNull);
        expect(result!.toUtc().year, greaterThan(2024));
      });

      test('parses ISO 8601 date strings', () {
        const isoDate = '2023-11-14T22:13:20Z';
        final result = TimestampParser.parseTimestamp(isoDate);

        expect(result, isNotNull);
        expect(result!.toUtc().year, equals(2023));
        expect(result.toUtc().month, equals(11));
        expect(result.toUtc().day, equals(14));
        expect(result.toUtc().hour, equals(22));
        expect(result.toUtc().minute, equals(13));
        expect(result.toUtc().second, equals(20));
      });

      test('parses ISO 8601 date strings without timezone', () {
        const isoDate = '2023-11-14T22:13:20';
        final result = TimestampParser.parseTimestamp(isoDate);

        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(11));
        expect(result.day, equals(14));
      });

      test('parses simple date strings', () {
        // Date-only ISO strings have no timezone marker, so DateTime.parse
        // interprets them in local time. Assert local fields to stay
        // TZ-independent.
        const simpleDate = '2023-11-14';
        final result = TimestampParser.parseTimestamp(simpleDate);

        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(11));
        expect(result.day, equals(14));
      });

      test('returns null for invalid input', () {
        expect(TimestampParser.parseTimestamp('not a timestamp'), isNull);
        expect(TimestampParser.parseTimestamp('abc123'), isNull);
        expect(TimestampParser.parseTimestamp('999999999999999999999'), isNull);
        expect(TimestampParser.parseTimestamp('invalid-date-format'), isNull);
      });

      test('handles edge cases', () {
        const oldTimestamp = '0';
        final oldResult = TimestampParser.parseTimestamp(oldTimestamp);
        expect(oldResult, isNotNull);
        expect(oldResult!.toUtc().year, equals(1970));

        const newTimestamp = '4102444800000';
        final newResult = TimestampParser.parseTimestamp(newTimestamp);
        expect(newResult, isNotNull);
        expect(newResult!.toUtc().year, equals(2100));
      });
    });

    group('isValidTimestamp', () {
      test('returns true for valid timestamps', () {
        expect(TimestampParser.isValidTimestamp('1700000000'), isTrue);
        expect(TimestampParser.isValidTimestamp('1700000000000'), isTrue);
        expect(
          TimestampParser.isValidTimestamp('2023-11-14T22:13:20Z'),
          isTrue,
        );
        expect(TimestampParser.isValidTimestamp('2023-11-14'), isTrue);
        expect(TimestampParser.isValidTimestamp('now'), isTrue);
      });

      test('returns false for invalid timestamps', () {
        expect(TimestampParser.isValidTimestamp(''), isFalse);
        expect(TimestampParser.isValidTimestamp('   '), isFalse);
        expect(TimestampParser.isValidTimestamp('not a timestamp'), isFalse);
        expect(TimestampParser.isValidTimestamp('abc123'), isFalse);
      });
    });

    group('parseAnyFormat — numeric width disambiguation', () {
      test('10-digit input is unixSeconds and ambiguous', () {
        final r = TimestampParser.parseAnyFormat('1700000000');
        expect(r.format, TimestampFormat.unixSeconds);
        expect(r.isAmbiguous, isTrue);
        expect(r.alternatives, hasLength(1));
        expect(r.alternatives.first.format, TimestampFormat.unixMilliseconds);
      });

      test('13-digit input is unixMilliseconds, not ambiguous', () {
        final r = TimestampParser.parseAnyFormat('1700000000000');
        expect(r.format, TimestampFormat.unixMilliseconds);
        expect(r.isAmbiguous, isFalse);
        expect(r.alternatives, isEmpty);
      });

      test('16-digit input is unixMicroseconds', () {
        final r = TimestampParser.parseAnyFormat('1700000000000000');
        expect(r.format, TimestampFormat.unixMicroseconds);
        expect(r.timestamp, isNotNull);
        expect(r.timestamp!.toUtc().year, greaterThanOrEqualTo(2023));
      });

      test('19-digit input is unixNanoseconds', () {
        final r = TimestampParser.parseAnyFormat('1700000000000000000');
        expect(r.format, TimestampFormat.unixNanoseconds);
        expect(r.timestamp, isNotNull);
        expect(r.timestamp!.toUtc().year, greaterThanOrEqualTo(2023));
      });

      test('round-trip across all four widths preserves the instant', () {
        final DateTime origin = DateTime.utc(2024, 6, 15, 12, 0, 0).toLocal();
        final int ms = origin.millisecondsSinceEpoch;
        final int s = ms ~/ 1000;
        final int us = ms * 1000;
        final int ns = ms * 1000000;

        final fromS = TimestampParser.parseAnyFormat('$s').timestamp!;
        final fromMs = TimestampParser.parseAnyFormat('$ms').timestamp!;
        final fromUs = TimestampParser.parseAnyFormat('$us').timestamp!;
        final fromNs = TimestampParser.parseAnyFormat('$ns').timestamp!;

        // Seconds resolution loses sub-second; align by truncating.
        expect(fromS.millisecondsSinceEpoch ~/ 1000, equals(s));
        expect(fromMs.millisecondsSinceEpoch, equals(ms));
        expect(fromUs.microsecondsSinceEpoch, equals(us));
        expect(fromNs.microsecondsSinceEpoch, equals(ns ~/ 1000));
      });

      test('20+ digit input returns unknown', () {
        final r = TimestampParser.parseAnyFormat('99999999999999999999');
        expect(r.format, TimestampFormat.unknown);
        expect(r.timestamp, isNull);
      });
    });

    group('parseAnyFormat — ISO naïve detection', () {
      test('ISO with Z suffix is not naïve', () {
        final r = TimestampParser.parseAnyFormat('2023-11-14T22:13:20Z');
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isFalse);
      });

      test('ISO with explicit offset is not naïve', () {
        final r = TimestampParser.parseAnyFormat('2023-11-14T22:13:20+09:00');
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isFalse);
      });

      test('ISO with explicit offset (no colon) is not naïve', () {
        final r = TimestampParser.parseAnyFormat('2023-11-14T22:13:20+0900');
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isFalse);
      });

      test('ISO without TZ is naïve', () {
        final r = TimestampParser.parseAnyFormat('2023-11-14T22:13:20');
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isTrue);
      });

      test('date-only ISO is not naïve', () {
        final r = TimestampParser.parseAnyFormat('2023-11-14');
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isFalse);
      });
    });

    group('parseAnyFormat — non-time inputs', () {
      test('hex-looking string is not parsed as time', () {
        // 48656c6c6f = "Hello" in ASCII; previously the encoded-fallthrough
        // would have decoded it. Now must return unknown.
        final r = TimestampParser.parseAnyFormat('48656c6c6f');
        expect(r.format, TimestampFormat.unknown);
        expect(r.timestamp, isNull);
      });

      test('base64-looking string is not parsed as time', () {
        final r = TimestampParser.parseAnyFormat('SGVsbG8=');
        expect(r.format, TimestampFormat.unknown);
        expect(r.timestamp, isNull);
      });

      test('empty input is unknown', () {
        final r = TimestampParser.parseAnyFormat('');
        expect(r.format, TimestampFormat.unknown);
      });
    });

    group('parseKeyword — closed set', () {
      // Saturday. weekday=6.
      final DateTime anchor = DateTime(2026, 5, 2, 14, 30, 45, 123);

      test('now preserves anchor exactly', () {
        final r = TimestampParser.parseKeyword('now', now: anchor);
        expect(r.format, TimestampFormat.keyword);
        expect(r.timestamp, equals(anchor));
      });

      test('day aliases match their explicit forms', () {
        for (final pair in <List<String>>[
          <String>['today', 'this day'],
          <String>['yesterday', 'last day'],
          <String>['tomorrow', 'next day'],
        ]) {
          final a = TimestampParser.parseKeyword(pair[0], now: anchor);
          final b = TimestampParser.parseKeyword(pair[1], now: anchor);
          expect(a.format, TimestampFormat.keyword);
          expect(b.format, TimestampFormat.keyword);
          expect(
            a.timestamp,
            equals(b.timestamp),
            reason: '${pair[0]} ≡ ${pair[1]}',
          );
        }
      });

      test('day anchors resolve correctly', () {
        expect(
          TimestampParser.parseKeyword('today', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2)),
        );
        expect(
          TimestampParser.parseKeyword('yesterday', now: anchor).timestamp,
          equals(DateTime(2026, 5, 1)),
        );
        expect(
          TimestampParser.parseKeyword('tomorrow', now: anchor).timestamp,
          equals(DateTime(2026, 5, 3)),
        );
      });

      test('second bucket', () {
        expect(
          TimestampParser.parseKeyword('this second', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 30, 45)),
        );
        expect(
          TimestampParser.parseKeyword('last second', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 30, 44)),
        );
        expect(
          TimestampParser.parseKeyword('next second', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 30, 46)),
        );
      });

      test('minute bucket', () {
        expect(
          TimestampParser.parseKeyword('this minute', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 30)),
        );
        expect(
          TimestampParser.parseKeyword('last minute', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 29)),
        );
        expect(
          TimestampParser.parseKeyword('next minute', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 31)),
        );
      });

      test('hour bucket', () {
        expect(
          TimestampParser.parseKeyword('this hour', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14)),
        );
        expect(
          TimestampParser.parseKeyword('last hour', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 13)),
        );
        expect(
          TimestampParser.parseKeyword('next hour', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 15)),
        );
      });

      test('week bucket — ISO Monday-start, anchored on Saturday', () {
        // 2026-05-02 is Saturday (weekday=6).
        expect(
          TimestampParser.parseKeyword('this week', now: anchor).timestamp,
          equals(DateTime(2026, 4, 27)),
        );
        expect(
          TimestampParser.parseKeyword('last week', now: anchor).timestamp,
          equals(DateTime(2026, 4, 20)),
        );
        expect(
          TimestampParser.parseKeyword('next week', now: anchor).timestamp,
          equals(DateTime(2026, 5, 4)),
        );
      });

      test('month bucket', () {
        expect(
          TimestampParser.parseKeyword('this month', now: anchor).timestamp,
          equals(DateTime(2026, 5, 1)),
        );
        expect(
          TimestampParser.parseKeyword('last month', now: anchor).timestamp,
          equals(DateTime(2026, 4, 1)),
        );
        expect(
          TimestampParser.parseKeyword('next month', now: anchor).timestamp,
          equals(DateTime(2026, 6, 1)),
        );
      });

      test('year bucket', () {
        expect(
          TimestampParser.parseKeyword('this year', now: anchor).timestamp,
          equals(DateTime(2026, 1, 1)),
        );
        expect(
          TimestampParser.parseKeyword('last year', now: anchor).timestamp,
          equals(DateTime(2025, 1, 1)),
        );
        expect(
          TimestampParser.parseKeyword('next year', now: anchor).timestamp,
          equals(DateTime(2027, 1, 1)),
        );
      });

      test('case insensitive', () {
        expect(
          TimestampParser.parseKeyword('YESTERDAY', now: anchor).format,
          TimestampFormat.keyword,
        );
        expect(
          TimestampParser.parseKeyword('Last Hour', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 13)),
        );
        expect(
          TimestampParser.parseKeyword('NEXT MINUTE', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14, 31)),
        );
      });

      test('whitespace tolerant', () {
        expect(
          TimestampParser.parseKeyword('  this  hour  ', now: anchor).timestamp,
          equals(DateTime(2026, 5, 2, 14)),
        );
      });

      test('rejects unrecognized tokens', () {
        for (final input in <String>[
          'next monday',
          'last decade',
          'in 5 minutes',
          '5 minutes ago',
          'today tomorrow',
          'thishour',
        ]) {
          final r = TimestampParser.parseKeyword(input, now: anchor);
          expect(
            r.format,
            TimestampFormat.unknown,
            reason: '"$input" should not match',
          );
          expect(r.timestamp, isNull);
        }
      });

      test('boundary: anchor on Monday → this week is same day', () {
        final mon = DateTime(2026, 5, 4, 12);
        expect(mon.weekday, equals(DateTime.monday));
        expect(
          TimestampParser.parseKeyword('this week', now: mon).timestamp,
          equals(DateTime(2026, 5, 4)),
        );
      });

      test(
        'boundary: anchor on Sunday (weekday=7) → this week is prior Mon',
        () {
          final sun = DateTime(2026, 5, 3, 12);
          expect(sun.weekday, equals(DateTime.sunday));
          expect(
            TimestampParser.parseKeyword('this week', now: sun).timestamp,
            equals(DateTime(2026, 4, 27)),
          );
        },
      );

      test('boundary: month-start rollover', () {
        final monthStart = DateTime(2026, 1, 1);
        expect(
          TimestampParser.parseKeyword('last month', now: monthStart).timestamp,
          equals(DateTime(2025, 12, 1)),
        );
        expect(
          TimestampParser.parseKeyword('last year', now: monthStart).timestamp,
          equals(DateTime(2025, 1, 1)),
        );
        expect(
          TimestampParser.parseKeyword('last day', now: monthStart).timestamp,
          equals(DateTime(2025, 12, 31)),
        );
      });

      test('boundary: year-end rollover', () {
        final yearEnd = DateTime(2026, 12, 31, 23, 59, 59);
        expect(
          TimestampParser.parseKeyword('next month', now: yearEnd).timestamp,
          equals(DateTime(2027, 1, 1)),
        );
        expect(
          TimestampParser.parseKeyword('next year', now: yearEnd).timestamp,
          equals(DateTime(2027, 1, 1)),
        );
        expect(
          TimestampParser.parseKeyword('next day', now: yearEnd).timestamp,
          equals(DateTime(2027, 1, 1)),
        );
      });

      test('boundary: midnight anchor', () {
        final midnight = DateTime(2026, 5, 2);
        expect(
          TimestampParser.parseKeyword('today', now: midnight).timestamp,
          equals(DateTime(2026, 5, 2)),
        );
        expect(
          TimestampParser.parseKeyword('last second', now: midnight).timestamp,
          equals(DateTime(2026, 5, 1, 23, 59, 59)),
        );
      });

      test('parseAnyFormat routes keyword inputs to keyword format', () {
        final r = TimestampParser.parseAnyFormat('today', now: anchor);
        expect(r.format, TimestampFormat.keyword);
        expect(r.timestamp, equals(DateTime(2026, 5, 2)));
      });

      test(
        'parseAnyFormat does not falsely match numeric/ISO inputs as keywords',
        () {
          final num = TimestampParser.parseAnyFormat('1700000000', now: anchor);
          expect(num.format, TimestampFormat.unixSeconds);

          final iso = TimestampParser.parseAnyFormat(
            '2023-11-14T22:13:20Z',
            now: anchor,
          );
          expect(iso.format, TimestampFormat.iso8601);
        },
      );
    });

    group('parseAs — explicit hint overrides heuristic', () {
      test('parseAs unixSeconds interprets digits as seconds', () {
        final r = TimestampParser.parseAs(
          '1700000000',
          TimestampFormat.unixSeconds,
        );
        expect(r.format, TimestampFormat.unixSeconds);
        expect(r.timestamp!.toUtc().year, equals(2023));
      });

      test('parseAs unixMilliseconds interprets the same digits as ms', () {
        final r = TimestampParser.parseAs(
          '1700000000',
          TimestampFormat.unixMilliseconds,
        );
        expect(r.format, TimestampFormat.unixMilliseconds);
        // 1.7e9 ms = early 1970 (~Jan 20, 1970).
        expect(r.timestamp!.toUtc().year, equals(1970));
      });

      test('parseAs unixMicroseconds', () {
        final r = TimestampParser.parseAs(
          '1700000000000000',
          TimestampFormat.unixMicroseconds,
        );
        expect(r.format, TimestampFormat.unixMicroseconds);
        expect(r.timestamp!.toUtc().year, equals(2023));
      });

      test('parseAs unixNanoseconds', () {
        final r = TimestampParser.parseAs(
          '1700000000000000000',
          TimestampFormat.unixNanoseconds,
        );
        expect(r.format, TimestampFormat.unixNanoseconds);
        expect(r.timestamp!.toUtc().year, equals(2023));
      });

      test('parseAs iso8601 sets isNaive when offset missing', () {
        final r = TimestampParser.parseAs(
          '2023-11-14T22:13:20',
          TimestampFormat.iso8601,
        );
        expect(r.format, TimestampFormat.iso8601);
        expect(r.isNaive, isTrue);
      });

      test('parseAs keyword honors injected now', () {
        final anchor = DateTime(2026, 5, 2, 14, 30, 45);
        final r = TimestampParser.parseAs(
          'this hour',
          TimestampFormat.keyword,
          now: anchor,
        );
        expect(r.format, TimestampFormat.keyword);
        expect(r.timestamp, equals(DateTime(2026, 5, 2, 14)));
      });

      test('parseAs unknown returns unknown', () {
        final r = TimestampParser.parseAs(
          '1700000000',
          TimestampFormat.unknown,
        );
        expect(r.format, TimestampFormat.unknown);
        expect(r.timestamp, isNull);
      });
    });

    group('kTimestampKeywords', () {
      test('exposes all 25 keywords for chip-row UI', () {
        expect(kTimestampKeywords.length, equals(25));
        expect(kTimestampKeywords, contains('now'));
        expect(kTimestampKeywords, contains('today'));
        expect(kTimestampKeywords, contains('this week'));
        expect(kTimestampKeywords, contains('next year'));
        expect(kTimestampKeywords, contains('last second'));
      });

      test('every keyword resolves via parseKeyword', () {
        final anchor = DateTime(2026, 5, 2, 14, 30, 45);
        for (final k in kTimestampKeywords) {
          final r = TimestampParser.parseKeyword(k, now: anchor);
          expect(
            r.format,
            TimestampFormat.keyword,
            reason: 'keyword "$k" should resolve',
          );
          expect(r.timestamp, isNotNull, reason: 'keyword "$k" timestamp');
        }
      });
    });
  });
}
