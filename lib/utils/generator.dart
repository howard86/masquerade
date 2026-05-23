import 'dart:convert';
import 'dart:math';

import 'uuid_parser.dart';

/// What the Generator tool produces.
enum GenMode { password, token, uuid }

/// Rendering for a random token's bytes.
enum TokenFormat { hex, base64url, alphanumeric }

/// Which UUID version to mint. Delegates to [UuidParser] so the dedicated UUID
/// tool and this generator share one implementation.
enum GenUuidVersion { v4, v7 }

/// Pure random-generation helpers for the Generator tool. All randomness comes
/// from [Random.secure]; no external dependency.
class Generator {
  const Generator._();

  static final Random _rng = Random.secure();

  static const String lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String digitChars = '0123456789';
  static const String symbolChars = r'!@#$%^&*()-_=+[]{};:,.<>?';
  static const String _alnum =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static const int minLength = 4;
  static const int maxLength = 256;
  static const int minBytes = 1;
  static const int maxBytes = 64;

  /// A random password of [length] drawn from the enabled character classes.
  /// Returns an empty string when no class is enabled or [length] <= 0.
  static String password({
    required int length,
    bool lower = true,
    bool upper = true,
    bool digits = true,
    bool symbols = true,
  }) {
    final StringBuffer pool = StringBuffer();
    if (lower) pool.write(lowerChars);
    if (upper) pool.write(upperChars);
    if (digits) pool.write(digitChars);
    if (symbols) pool.write(symbolChars);
    final String chars = pool.toString();
    if (chars.isEmpty || length <= 0) return '';
    return List<String>.generate(
      length,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }

  /// A random token rendered in [format]. [byteCount] random bytes back the
  /// hex and base64url forms; the alphanumeric form emits [byteCount] random
  /// characters from a 62-symbol alphabet (unbiased, no modulo).
  static String token({
    required int byteCount,
    TokenFormat format = TokenFormat.hex,
  }) {
    if (byteCount <= 0) return '';
    switch (format) {
      case TokenFormat.hex:
        final List<int> bytes = _randomBytes(byteCount);
        return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
      case TokenFormat.base64url:
        final List<int> bytes = _randomBytes(byteCount);
        return base64Url.encode(bytes).replaceAll('=', '');
      case TokenFormat.alphanumeric:
        return List<String>.generate(
          byteCount,
          (_) => _alnum[_rng.nextInt(_alnum.length)],
        ).join();
    }
  }

  /// A fresh UUID of the requested version, via the shared [UuidParser].
  static String uuid(GenUuidVersion version) => switch (version) {
    GenUuidVersion.v4 => UuidParser.generateV4(),
    GenUuidVersion.v7 => UuidParser.generateV7(),
  };

  static List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => _rng.nextInt(256));
}
