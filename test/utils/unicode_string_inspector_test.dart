import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/unicode_string_inspector.dart';

void main() {
  test('computes all normalization forms including Hangul', () {
    final UnicodeInspection decomposed = UnicodeStringInspector.parse(
      'e\u0301 \u1100\u1161',
    );
    expect(decomposed.normalizedAs(UnicodeNormalization.nfc), '\u00e9 \uac00');
    expect(
      decomposed.normalizedAs(UnicodeNormalization.nfd),
      'e\u0301 \u1100\u1161',
    );

    final UnicodeInspection compatibility = UnicodeStringInspector.parse(
      '\ufb03 \u2460 \uff21',
    );
    expect(compatibility.normalizedAs(UnicodeNormalization.nfkc), 'ffi 1 A');
    expect(compatibility.normalizedAs(UnicodeNormalization.nfkd), 'ffi 1 A');
    expect(
      compatibility.normalizedAs(UnicodeNormalization.nfc),
      '\ufb03 \u2460 \uff21',
    );
  });

  test('keeps extended emoji grapheme clusters whole', () {
    final UnicodeInspection result = UnicodeStringInspector.parse(
      '👨‍👩‍👧‍👦 👍🏽 🇹🇼 e\u0301',
    );

    expect(result.graphemes.map((UnicodeGrapheme item) => item.text), <String>[
      '👨‍👩‍👧‍👦',
      ' ',
      '👍🏽',
      ' ',
      '🇹🇼',
      ' ',
      'e\u0301',
    ]);
    expect(result.graphemes.first.codePoints, hasLength(7));
    expect(result.graphemes[2].codePoints, hasLength(2));
    expect(result.graphemes[4].codePoints, hasLength(2));
  });

  test('shows code points and UTF-8 bytes for each grapheme', () {
    final UnicodeGrapheme value = UnicodeStringInspector.parse(
      'é',
    ).graphemes.single;

    expect(value.codePointLabel, 'U+00E9');
    expect(value.byteLabel, 'C3 A9');
  });

  test('identifies invisible and bidi controls in visible output', () {
    final UnicodeInspection result = UnicodeStringInspector.parse(
      'a\u200bb\u202ec\u2069\ufeff',
    );

    expect(
      result.graphemes.map((UnicodeGrapheme item) => item.display).join(),
      contains('⟦ZERO WIDTH SPACE⟧'),
    );
    expect(
      result.graphemes.expand((UnicodeGrapheme item) => item.markers),
      containsAll(<String>[
        'RIGHT-TO-LEFT OVERRIDE',
        'POP DIRECTIONAL ISOLATE',
        'BYTE ORDER MARK',
      ]),
    );
    expect(result.warnings, contains(contains('Bidirectional controls')));
  });

  test('counts CRLF, CR, and LF without double counting', () {
    final UnicodeInspection result = UnicodeStringInspector.parse(
      'one\r\ntwo\rthree\nfour',
    );

    expect(result.lineEndings.crlf, 1);
    expect(result.lineEndings.cr, 1);
    expect(result.lineEndings.lf, 1);
    expect(result.lineEndings.total, 3);
    expect(result.lineEndings.mixed, isTrue);
    expect(result.warnings, contains('Mixed line endings detected.'));
  });

  test('warns conservatively about mixed Latin and Cyrillic text', () {
    final UnicodeInspection result = UnicodeStringInspector.parse(
      'pаypal', // second character is Cyrillic small a
    );

    expect(result.warnings, contains(contains('Possible confusable text')));
    expect(result.warnings, contains(contains('Latin/Cyrillic')));
  });

  test(
    'does not flag a single-script Cyrillic word as a confusable attack',
    () {
      final UnicodeInspection result = UnicodeStringInspector.parse('привет');

      expect(result.warnings, isNot(contains(contains('Possible confusable'))));
    },
  );

  test('does not flag accented Latin or emoji as mixed-script confusables', () {
    expect(
      UnicodeStringInspector.parse('café').warnings,
      isNot(contains(contains('Possible confusable'))),
    );
    expect(
      UnicodeStringInspector.parse('hello 😀').warnings,
      isNot(contains(contains('Possible confusable'))),
    );
  });

  test('reports changed forms without mutating input', () {
    const String input = 'e\u0301';
    final UnicodeInspection result = UnicodeStringInspector.parse(input);

    expect(result.input, input);
    expect(result.changes(UnicodeNormalization.nfc), isTrue);
    expect(result.normalizedAs(UnicodeNormalization.nfc), 'é');
    expect(result.changes(UnicodeNormalization.nfd), isFalse);
  });

  test('bounds displayed graphemes while preserving totals and order', () {
    final String input = List<String>.generate(
      UnicodeStringInspector.maxDisplayedGraphemes + 25,
      (int index) => index.isEven ? 'a' : '😀',
    ).join();
    final Stopwatch watch = Stopwatch()..start();
    final UnicodeInspection result = UnicodeStringInspector.parse(input);
    watch.stop();

    expect(result.truncated, isTrue);
    expect(
      result.graphemes,
      hasLength(UnicodeStringInspector.maxDisplayedGraphemes),
    );
    expect(
      result.graphemeCount,
      UnicodeStringInspector.maxDisplayedGraphemes + 25,
    );
    expect(result.graphemes.first.text, 'a');
    expect(result.graphemes.last.text, '😀');
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('rejects oversized text before building result collections', () {
    expect(
      () => UnicodeStringInspector.parse(
        'a' * (UnicodeStringInspector.maxInputCodeUnits + 1),
      ),
      throwsA(isA<UnicodeInspectorException>()),
    );
  });

  test('rejects malformed UTF-16 with a stable domain error', () {
    expect(
      () => UnicodeStringInspector.parse(String.fromCharCode(0xd800)),
      throwsA(
        isA<UnicodeInspectorException>().having(
          (UnicodeInspectorException error) => error.message,
          'message',
          'Text contains malformed UTF-16.',
        ),
      ),
    );
  });

  test(
    'rejects pathological clusters before normalization becomes quadratic',
    () {
      final Stopwatch watch = Stopwatch()..start();
      expect(
        () =>
            UnicodeStringInspector.parse('a${'\u0315' * 513}${'\u0300' * 512}'),
        throwsA(
          isA<UnicodeInspectorException>().having(
            (UnicodeInspectorException error) => error.message,
            'message',
            contains('1,024-code-point limit'),
          ),
        ),
      );
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );
}
