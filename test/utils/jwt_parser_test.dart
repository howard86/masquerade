import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/jwt_parser.dart';

void main() {
  // Hand-built fixture: header = {"alg":"HS256"}, payload = {"sub":"123","exp":1700000000}
  const String token =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.sig';

  group('JwtParser.parse — valid token', () {
    test('decodes header correctly', () {
      final JwtParseResult r = JwtParser.parse(token);
      expect(r, isA<JwtOk>());
      final JwtOk ok = r as JwtOk;
      expect(ok.header, <String, dynamic>{'alg': 'HS256'});
    });

    test('decodes payload correctly', () {
      final JwtOk ok = JwtParser.parse(token) as JwtOk;
      expect(ok.payload, <String, dynamic>{'sub': '123', 'exp': 1700000000});
    });

    test('extracts signature segment', () {
      final JwtOk ok = JwtParser.parse(token) as JwtOk;
      expect(ok.signature, 'sig');
    });

    test('parses expiresAt from exp claim', () {
      final JwtOk ok = JwtParser.parse(token) as JwtOk;
      expect(
        ok.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('isExpired is true when now is after exp', () {
      final JwtOk ok =
          JwtParser.parse(token, now: DateTime.utc(2026, 1, 1)) as JwtOk;
      expect(ok.isExpired, isTrue);
    });

    test('isExpired is false when now is before exp', () {
      final JwtOk ok =
          JwtParser.parse(token, now: DateTime.utc(2023, 1, 1)) as JwtOk;
      expect(ok.isExpired, isFalse);
    });

    test('isNotYetValid is false when nbf is absent', () {
      final JwtOk ok = JwtParser.parse(token) as JwtOk;
      expect(ok.isNotYetValid, isFalse);
    });

    test('empty signature is accepted (alg:none)', () {
      // header = {"alg":"none"}, payload = {"sub":"x"}
      const String noneToken = 'eyJhbGciOiJub25lIn0.eyJzdWIiOiJ4In0.';
      final JwtParseResult r = JwtParser.parse(noneToken);
      expect(r, isA<JwtOk>());
      expect((r as JwtOk).signature, isEmpty);
    });
  });

  group('JwtParser.parse — error cases', () {
    test('two segments returns JwtErr', () {
      final JwtParseResult r = JwtParser.parse('abc.def');
      expect(r, isA<JwtErr>());
      expect((r as JwtErr).message, contains('3 segments'));
    });

    test('four segments returns JwtErr', () {
      final JwtParseResult r = JwtParser.parse('a.b.c.d');
      expect(r, isA<JwtErr>());
    });

    test('non-base64url chars in header returns JwtErr', () {
      // '+' and '/' are standard base64 but not url-safe; however the parser
      // should still attempt decode. The real failure is non-JSON content.
      final JwtParseResult r = JwtParser.parse('!!!.abc.def');
      expect(r, isA<JwtErr>());
    });

    test('non-JSON header returns JwtErr', () {
      // base64url of "not json" = bm90IGpzb24
      final JwtParseResult r = JwtParser.parse('bm90IGpzb24.eyJhIjoxfQ.sig');
      expect(r, isA<JwtErr>());
    });

    test('non-JSON payload returns JwtErr', () {
      // valid header, but payload decodes to non-JSON
      final JwtParseResult r = JwtParser.parse(
        'eyJhbGciOiJIUzI1NiJ9.bm90IGpzb24.sig',
      );
      expect(r, isA<JwtErr>());
    });
  });

  group('JwtParser.parse — edge cases', () {
    test('tolerates non-numeric exp (leaves expiresAt null)', () {
      // payload = {"exp":"not_a_number"}
      // base64url("{"exp":"not_a_number"}") = eyJleHAiOiJub3RfYV9udW1iZXIifQ
      const String t =
          'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOiJub3RfYV9udW1iZXIifQ.sig';
      final JwtOk ok = JwtParser.parse(t) as JwtOk;
      expect(ok.expiresAt, isNull);
    });

    test('trims whitespace around input', () {
      final JwtParseResult r = JwtParser.parse('  $token  ');
      expect(r, isA<JwtOk>());
    });
  });
}
