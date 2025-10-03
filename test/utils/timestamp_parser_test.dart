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
        // January 1, 2023 00:00:00 UTC
        const timestampSeconds = '1672531200';
        final result = TimestampParser.parseTimestamp(timestampSeconds);

        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(1));
        expect(result.day, equals(1));
      });

      test('parses Unix timestamp in milliseconds', () {
        // January 1, 2023 00:00:00 UTC in milliseconds
        const timestampMillis = '1672531200000';
        final result = TimestampParser.parseTimestamp(timestampMillis);

        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(1));
        expect(result.day, equals(1));
      });

      test('parses JavaScript Date.now() timestamp', () {
        // Example from user: 1759493075163
        const jsTimestamp = '1759493075163';
        final result = TimestampParser.parseTimestamp(jsTimestamp);

        expect(result, isNotNull);
        // This should be a date in 2025 (future timestamp)
        expect(result!.year, greaterThan(2024));
      });

      test('parses ISO 8601 date strings', () {
        const isoDate = '2023-11-14T22:13:20Z';
        final result = TimestampParser.parseTimestamp(isoDate);

        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(11));
        expect(result.day, equals(14));
        expect(result.hour, equals(22));
        expect(result.minute, equals(13));
        expect(result.second, equals(20));
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
        expect(
          TimestampParser.parseTimestamp('999999999999999999999'),
          isNull,
        ); // Too large
        expect(TimestampParser.parseTimestamp('invalid-date-format'), isNull);
      });

      test('handles edge cases', () {
        // Very old timestamp (seconds)
        const oldTimestamp = '0';
        final oldResult = TimestampParser.parseTimestamp(oldTimestamp);
        expect(oldResult, isNotNull);
        expect(oldResult!.year, equals(1970));

        // Very new timestamp (milliseconds)
        const newTimestamp = '4102444800000'; // Year 2100
        final newResult = TimestampParser.parseTimestamp(newTimestamp);
        expect(newResult, isNotNull);
        expect(newResult!.year, equals(2100));
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
      });

      test('returns false for invalid timestamps', () {
        expect(TimestampParser.isValidTimestamp(''), isFalse);
        expect(TimestampParser.isValidTimestamp('   '), isFalse);
        expect(TimestampParser.isValidTimestamp('not a timestamp'), isFalse);
        expect(TimestampParser.isValidTimestamp('abc123'), isFalse);
      });
    });
  });
}
