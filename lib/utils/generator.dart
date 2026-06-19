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
  ///
  /// Guarantees at least one character from each ENABLED class so "must contain
  /// a digit/symbol" policies always hold: one char per class is reserved, the
  /// remaining slots are filled from the merged pool, then the whole result is
  /// shuffled so the reserved chars aren't positionally predictable. When
  /// [length] < the number of enabled classes, only the first [length] classes
  /// get a guaranteed char (no crash); the shortfall is unavoidable.
  ///
  /// [random] is the RNG seam — pass a seeded [Random] for deterministic tests;
  /// it defaults to a cryptographically secure source.
  static String password({
    required int length,
    bool lower = true,
    bool upper = true,
    bool digits = true,
    bool symbols = true,
    Random? random,
  }) {
    final Random rng = random ?? _rng;
    final List<String> classes = <String>[
      if (lower) lowerChars,
      if (upper) upperChars,
      if (digits) digitChars,
      if (symbols) symbolChars,
    ];
    if (classes.isEmpty || length <= 0) return '';
    final String pool = classes.join();

    // One guaranteed char per enabled class (capped at [length] when too short).
    final List<String> chars = <String>[
      for (final String cls in classes.take(length))
        cls[rng.nextInt(cls.length)],
    ];
    // Fill the remaining slots from the merged pool.
    while (chars.length < length) {
      chars.add(pool[rng.nextInt(pool.length)]);
    }
    chars.shuffle(rng);
    return chars.join();
  }

  /// Shannon entropy in bits for a password of [length] drawn from a pool of
  /// [poolSize] symbols: `length * log2(poolSize)`. Returns 0 when either input
  /// is non-positive (an empty pool or zero-length carries no entropy).
  static double entropyBits(int length, int poolSize) {
    if (length <= 0 || poolSize <= 0) return 0;
    return length * (log(poolSize) / ln2);
  }

  /// A random token rendered in [format]. [byteCount] random bytes back the
  /// hex and base64url forms; the alphanumeric form emits [byteCount] random
  /// characters from a 62-symbol alphabet (unbiased, no modulo). Pass [random]
  /// to inject a seeded [Random] for deterministic tests; defaults to the
  /// secure RNG.
  static String token({
    required int byteCount,
    TokenFormat format = TokenFormat.hex,
    Random? random,
  }) {
    final Random rng = random ?? _rng;
    if (byteCount <= 0) return '';
    switch (format) {
      case TokenFormat.hex:
        final List<int> bytes = _randomBytes(byteCount, rng);
        return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
      case TokenFormat.base64url:
        final List<int> bytes = _randomBytes(byteCount, rng);
        return base64Url.encode(bytes).replaceAll('=', '');
      case TokenFormat.alphanumeric:
        return List<String>.generate(
          byteCount,
          (_) => _alnum[rng.nextInt(_alnum.length)],
        ).join();
    }
  }

  /// A fresh UUID of the requested version, via the shared [UuidParser].
  static String uuid(GenUuidVersion version) => switch (version) {
    GenUuidVersion.v4 => UuidParser.generateV4(),
    GenUuidVersion.v7 => UuidParser.generateV7(),
  };

  static List<int> _randomBytes(int n, Random rng) =>
      List<int>.generate(n, (_) => rng.nextInt(256));
}
