import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/utility_catalog.dart';

void main() {
  List<String> ids(String input) => UtilityCatalog.detectAll(
    input,
  ).map((UtilityDescriptor u) => u.id).toList();

  group('UtilityCatalog.detectAll', () {
    test('empty / whitespace returns no candidates', () {
      expect(ids(''), isEmpty);
      expect(ids('   '), isEmpty);
      expect(ids('\n\t'), isEmpty);
    });

    test('JSON object only suggests JSON', () {
      expect(ids('{"a":1}'), <String>['json']);
    });

    test('JSON array of small ints co-fires JSON + Bytes', () {
      // Bracketed integer list parses as JSON and as a byte array.
      expect(ids('[1, 2, 3]'), <String>['json', 'bytes']);
    });

    test('space-separated bytes only suggests Bytes', () {
      expect(ids('72 101 108 108 111'), <String>['bytes']);
    });

    test('bracketed byte list co-fires JSON + Bytes', () {
      expect(ids('[72, 101, 108, 108, 111]'), <String>['json', 'bytes']);
    });

    test('single integer does not suggest Bytes', () {
      // Single tokens stay with Number Base / Timestamp.
      expect(ids('72'), isNot(contains('bytes')));
    });

    test('out-of-range list does not suggest Bytes', () {
      expect(ids('256 1 2'), isNot(contains('bytes')));
    });

    test('hex color with # only suggests Color', () {
      expect(ids('#ff5733'), <String>['color']);
    });

    test('bare hex string suggests Number Base + Color, not Base64', () {
      // ff5733 is valid as hex digits → number base, also a 6-char hex color.
      // Base64 detection rejects pure-hex strings without padding.
      expect(ids('ff5733'), <String>['number_base', 'color']);
    });

    test('unix seconds suggests Timestamp + Number Base, not bps', () {
      // 1700000000 has length 10, not divisible by 4, so isBase64 rejects.
      // bps detector requires explicit suffix or abs ≤ 1, so it stays quiet.
      expect(ids('1700000000'), <String>['number_base', 'timestamp']);
    });

    test('arithmetic expression suggests Math only', () {
      expect(ids('2+2'), <String>['math']);
      expect(ids('2 * (3 + 4)'), <String>['math']);
      expect(ids('100 - 1'), <String>['math']);
    });

    test('math function name triggers Math', () {
      expect(ids('sin(pi/2)'), <String>['math']);
      expect(ids('log(100)'), <String>['math']);
    });

    test('constant pi alone triggers Math', () {
      expect(ids('pi'), <String>['math']);
    });

    test('lone integer does not trigger Math', () {
      // Math should not poach single numbers — those belong to Number Base
      // / Timestamp / bps depending on shape.
      expect(ids('42'), isNot(contains('math')));
    });

    test('leading sign alone does not trigger Math', () {
      // `-42` is a single negative number, not an expression.
      expect(ids('-42'), isNot(contains('math')));
    });

    test('hex literal does not trigger Math', () {
      // `0xFF` is owned by Number Base — Math has no multi-base literal
      // support.
      expect(ids('0xFF'), isNot(contains('math')));
    });

    test('ISO date does not trigger Math', () {
      // Hyphens in dates would otherwise read as subtraction; the date-shape
      // guard in _detectMath keeps these timestamp-only.
      expect(ids('2026-05-15'), isNot(contains('math')));
    });

    test('JSON does not trigger Math', () {
      expect(ids('{"a":1}'), isNot(contains('math')));
    });

    test('YAML map with ≥2 keys suggests JSON tool', () {
      expect(ids('a: 1\nb: hello'), contains('json'));
    });

    test('single YAML key does not suggest JSON tool', () {
      // Single `foo: bar` is ambiguous and noisy — keep the chip quiet.
      expect(ids('foo: bar'), isNot(contains('json')));
    });

    test('YAML doc separator suggests JSON tool', () {
      expect(ids('---\na: 1'), contains('json'));
    });

    test('TOML table header suggests JSON tool', () {
      expect(ids('[server]\nport = 8080'), contains('json'));
    });

    test('TOML bare key/value (≥2 lines) suggests JSON tool', () {
      expect(ids('title = "x"\ncount = 3'), contains('json'));
    });

    test('single TOML-shaped line does not suggest JSON tool', () {
      // Single `KEY = value` matches env files / shell snippets too.
      expect(ids('FOO = bar'), isNot(contains('json')));
    });

    test('5-field cron only suggests Cron', () {
      expect(ids('0 9 * * 1'), <String>['cron']);
    });

    test('cron macro only suggests Cron', () {
      expect(ids('@daily'), <String>['cron']);
    });

    test('NL phrase only suggests Cron', () {
      expect(ids('every monday at 9am'), <String>['cron']);
    });

    test('NL macro phrase only suggests Cron', () {
      expect(ids('hourly'), <String>['cron']);
    });

    test('weekdays alone only suggests Cron', () {
      expect(ids('weekdays'), <String>['cron']);
    });

    test('non-grammar English does not suggest Cron', () {
      expect(ids('every dog has its day'), isEmpty);
      expect(ids('penguins ride bicycles'), isEmpty);
    });

    test('star expression only suggests Cron', () {
      expect(ids('* * * * *'), <String>['cron']);
    });

    test('unix milliseconds suggests Timestamp + Number Base', () {
      expect(ids('1700000000000'), <String>['number_base', 'timestamp']);
    });

    test('ISO 8601 only suggests Timestamp', () {
      expect(ids('2023-11-14T22:13:20Z'), <String>['timestamp']);
    });

    test('Base64 with padding only suggests Base64', () {
      // SGVsbG8= decodes to "Hello" — printable bytes pass the gate.
      expect(ids('SGVsbG8='), <String>['base64']);
    });

    test('explicit bps suffix only suggests bps', () {
      expect(ids('25 bps'), <String>['bps']);
    });

    test('percent suffix only suggests bps', () {
      expect(ids('0.25%'), <String>['bps']);
    });

    test('small decimal without suffix only suggests bps', () {
      expect(ids('0.05'), <String>['bps']);
    });

    test('rgb() function only suggests Color', () {
      expect(ids('rgb(255, 0, 0)'), <String>['color']);
    });

    test('hsl() function only suggests Color', () {
      expect(ids('hsl(184, 100%, 38%)'), <String>['color']);
    });

    test('0x prefix only suggests Number Base', () {
      expect(ids('0xFF'), <String>['number_base']);
    });

    test('binary prefix only suggests Number Base', () {
      expect(ids('0b1010'), <String>['number_base']);
    });

    test('garbage input returns no candidates', () {
      expect(ids('!@#\$%^&*()'), isEmpty);
      expect(ids('not a real input ~~~'), isEmpty);
    });

    test('bulleted multi-line list only suggests List', () {
      expect(ids('- BTCUSDT\n- ETHUSDT\n- SOLUSDT'), <String>['list']);
    });

    test('numbered multi-line list suggests List', () {
      expect(ids('1. first\n2. second\n3. third'), contains('list'));
    });

    test('single bulleted line does not suggest List', () {
      expect(ids('- BTCUSDT'), isNot(contains('list')));
    });

    test('multi-line prose does not suggest List', () {
      expect(
        ids('the quick brown fox\njumped over the lazy dog'),
        isNot(contains('list')),
      );
    });
  });
}
