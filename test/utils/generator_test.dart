import 'dart:math';

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

    test('guarantees >=1 char from every enabled class over 100 draws', () {
      final RegExp lower = RegExp('[a-z]');
      final RegExp upper = RegExp('[A-Z]');
      final RegExp digit = RegExp('[0-9]');
      // Symbols are everything from the symbol class; check via the constant.
      bool hasSymbol(String s) =>
          s.split('').any(Generator.symbolChars.contains);

      for (int i = 0; i < 100; i++) {
        // length 12 >> the 4 enabled classes, so the guarantee fully holds.
        final String pw = Generator.password(length: 12, random: Random(i));
        expect(lower.hasMatch(pw), isTrue, reason: 'no lowercase in "$pw"');
        expect(upper.hasMatch(pw), isTrue, reason: 'no uppercase in "$pw"');
        expect(digit.hasMatch(pw), isTrue, reason: 'no digit in "$pw"');
        expect(hasSymbol(pw), isTrue, reason: 'no symbol in "$pw"');
      }
    });

    test(
      'a subset guarantees its classes and never includes disabled ones',
      () {
        for (int i = 0; i < 100; i++) {
          final String pw = Generator.password(
            length: 8,
            lower: true,
            upper: false,
            digits: true,
            symbols: false,
            random: Random(i),
          );
          expect(RegExp(r'^[a-z0-9]+$').hasMatch(pw), isTrue);
          expect(RegExp('[a-z]').hasMatch(pw), isTrue, reason: 'missing lower');
          expect(RegExp('[0-9]').hasMatch(pw), isTrue, reason: 'missing digit');
        }
      },
    );

    test(
      'length < enabled classes: includes as many classes as fit, no crash',
      () {
        // 4 classes enabled but length 2 — exactly 2 distinct classes guaranteed.
        final String pw = Generator.password(length: 2, random: Random(7));
        expect(pw.length, 2);
        final Set<String> classesPresent = <String>{
          if (RegExp('[a-z]').hasMatch(pw)) 'lower',
          if (RegExp('[A-Z]').hasMatch(pw)) 'upper',
          if (RegExp('[0-9]').hasMatch(pw)) 'digit',
          if (pw.split('').any(Generator.symbolChars.contains)) 'symbol',
        };
        expect(classesPresent.length, 2);

        // length 1 with all classes: one class, still no crash.
        expect(Generator.password(length: 1, random: Random(7)).length, 1);
      },
    );
  });

  group('Generator.entropyBits', () {
    test('returns length * log2(poolSize) for known pairs', () {
      // poolSize 64 = log2 6 bits/char.
      expect(Generator.entropyBits(20, 64), closeTo(120, 1e-9));
      // poolSize 2 = 1 bit/char.
      expect(Generator.entropyBits(10, 2), closeTo(10, 1e-9));
      // Full 94-symbol pool, length 20.
      expect(
        Generator.entropyBits(20, 94),
        closeTo(20 * (log(94) / ln2), 1e-9),
      );
    });

    test('non-positive length or pool carries no entropy', () {
      expect(Generator.entropyBits(0, 64), 0);
      expect(Generator.entropyBits(20, 0), 0);
      expect(Generator.entropyBits(-1, 64), 0);
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

    test('seeded Random yields a stable hex token', () {
      final String t = Generator.token(
        byteCount: 8,
        format: TokenFormat.hex,
        random: Random(42),
      );
      expect(t, '33aec45db5688f3d');
      expect(t.length, 16);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(t), isTrue);
    });

    test('seeded Random yields a stable base64url token', () {
      final String t = Generator.token(
        byteCount: 8,
        format: TokenFormat.base64url,
        random: Random(42),
      );
      expect(t, 'M67EXbVojz0');
      expect(t.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t), isTrue);
    });

    test('seeded Random yields a stable alphanumeric token', () {
      final String t = Generator.token(
        byteCount: 12,
        format: TokenFormat.alphanumeric,
        random: Random(42),
      );
      expect(t, 'P6i7ziZpaqNE');
      expect(t.length, 12);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(t), isTrue);
    });

    test(
      'byteCount <= 0 returns empty for every format and does not crash',
      () {
        for (final TokenFormat f in TokenFormat.values) {
          expect(
            Generator.token(byteCount: 0, format: f, random: Random(7)),
            '',
          );
          expect(
            Generator.token(byteCount: -3, format: f, random: Random(7)),
            '',
          );
        }
      },
    );

    test('byteCount of 1 produces a minimal token per format', () {
      expect(
        Generator.token(
          byteCount: 1,
          format: TokenFormat.hex,
          random: Random(1),
        ).length,
        2,
      );
      expect(
        Generator.token(
          byteCount: 1,
          format: TokenFormat.alphanumeric,
          random: Random(1),
        ).length,
        1,
      );
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
