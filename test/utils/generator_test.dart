import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/generator.dart';
import 'package:masquerade/utils/uuid_parser.dart';

void main() {
  group('Generator.password', () {
    test('respects requested length', () {
      expect(Generator.password(length: 20).length, 20);
      expect(Generator.password(length: 4).length, 4);
    });

    test('uses only the enabled character classes', () {
      final String digitsOnly = Generator.password(
        length: 64,
        lower: false,
        upper: false,
        digits: true,
        symbols: false,
      );
      expect(RegExp(r'^[0-9]+$').hasMatch(digitsOnly), isTrue);

      final String lowerOnly = Generator.password(
        length: 64,
        lower: true,
        upper: false,
        digits: false,
        symbols: false,
      );
      expect(RegExp(r'^[a-z]+$').hasMatch(lowerOnly), isTrue);
    });

    test('returns empty when no class is enabled', () {
      expect(
        Generator.password(
          length: 16,
          lower: false,
          upper: false,
          digits: false,
          symbols: false,
        ),
        isEmpty,
      );
    });

    test('100 generations are distinct (secure RNG)', () {
      final Set<String> seen = <String>{
        for (int i = 0; i < 100; i++) Generator.password(length: 24),
      };
      expect(seen.length, 100);
    });
  });

  group('Generator.token', () {
    test('hex is 2 chars per byte, lowercase hex alphabet', () {
      final String t = Generator.token(byteCount: 16, format: TokenFormat.hex);
      expect(t.length, 32);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(t), isTrue);
    });

    test('base64url uses the url-safe alphabet with no padding', () {
      final String t = Generator.token(
        byteCount: 16,
        format: TokenFormat.base64url,
      );
      expect(t.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t), isTrue);
    });

    test('alphanumeric emits byteCount chars from a 62-symbol alphabet', () {
      final String t = Generator.token(
        byteCount: 24,
        format: TokenFormat.alphanumeric,
      );
      expect(t.length, 24);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(t), isTrue);
    });

    test('100 hex tokens are distinct', () {
      final Set<String> seen = <String>{
        for (int i = 0; i < 100; i++)
          Generator.token(byteCount: 16, format: TokenFormat.hex),
      };
      expect(seen.length, 100);
    });
  });

  group('Generator.uuid (reuses UuidParser)', () {
    test('v4 produces a valid version-4 UUID', () {
      final String u = Generator.uuid(GenUuidVersion.v4);
      final UuidParseResult r = UuidParser.parse(u);
      expect(r, isA<UuidOk>());
      expect((r as UuidOk).version, 4);
    });

    test('v7 produces a valid version-7 UUID with a timestamp', () {
      final String u = Generator.uuid(GenUuidVersion.v7);
      final UuidParseResult r = UuidParser.parse(u);
      expect(r, isA<UuidOk>());
      final UuidOk ok = r as UuidOk;
      expect(ok.version, 7);
      expect(ok.timestamp, isNotNull);
    });
  });
}
