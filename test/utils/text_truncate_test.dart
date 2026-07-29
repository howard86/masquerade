import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/text_truncate.dart';

void main() {
  group('truncateWithEllipsis', () {
    test('returns string shorter than max unchanged (no ellipsis)', () {
      expect(truncateWithEllipsis('abc', max: 10), 'abc');
    });

    test('returns string equal to max unchanged (boundary)', () {
      expect(truncateWithEllipsis('abcde', max: 5), 'abcde');
    });

    test('truncates string longer than max and appends a single ellipsis', () {
      // Ellipsis is appended, NOT counted toward max: 5 chars + '…'.
      expect(truncateWithEllipsis('abcdefgh', max: 5), 'abcde…');
    });

    test('truncating by one char keeps max chars plus ellipsis', () {
      expect(truncateWithEllipsis('abcdef', max: 5), 'abcde…');
    });

    test('max == 0 on a non-empty string returns just the ellipsis', () {
      expect(truncateWithEllipsis('abc', max: 0), '…');
    });

    test('empty string returns empty regardless of max', () {
      expect(truncateWithEllipsis('', max: 5), '');
      expect(truncateWithEllipsis('', max: 0), '');
    });

    test('uses the single ellipsis character (…), not three dots', () {
      final String result = truncateWithEllipsis('abcdef', max: 3);
      expect(result, 'abc…');
      expect(result.endsWith('…'), isTrue);
      expect(result.endsWith('...'), isFalse);
    });

    test('negative max is clamped to 0 instead of throwing', () {
      expect(truncateWithEllipsis('abc', max: -5), '…');
    });

    test('max greater than length returns the original string unchanged', () {
      expect(truncateWithEllipsis('abc', max: 100), 'abc');
    });

    test(
      'cutting mid-surrogate-pair backs off instead of splitting the emoji',
      () {
        // U+1F600 (😀) is a surrogate pair in UTF-16: 2 code units.
        // 'ab😀cd' is 6 code units long; max: 3 lands the cut between the
        // high and low surrogate, so it must back off to max: 2.
        final String result = truncateWithEllipsis('ab😀cd', max: 3);
        expect(result, 'ab…');
        // No lone surrogate left dangling in the output.
        expect(() => result.runes.toList(), returnsNormally);
      },
    );
  });
}
