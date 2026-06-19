import 'dart:math';

sealed class UuidParseResult {}

class UuidOk extends UuidParseResult {
  UuidOk({
    required this.canonical,
    required this.version,
    required this.variant,
    this.timestamp,
  });

  final String canonical;
  final int version;
  final int variant;
  final DateTime? timestamp;
}

class UlidOk extends UuidParseResult {
  UlidOk({required this.canonical, required this.timestamp});

  final String canonical;
  final DateTime timestamp;
}

class UuidErr extends UuidParseResult {
  UuidErr(this.message);
  final String message;
}

class UuidParser {
  static final RegExp _dashed = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _plain = RegExp(r'^[0-9a-fA-F]{32}$');
  static final RegExp _ulid = RegExp(r'^[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{26}$');

  static UuidParseResult parse(String input) {
    final String t = input.trim();
    if (t.isEmpty) return UuidErr('Empty input');

    if (_dashed.hasMatch(t)) return _parseUuid(t.replaceAll('-', ''));
    if (_plain.hasMatch(t)) return _parseUuid(t);
    if (_ulid.hasMatch(t)) return _parseUlid(t);

    return UuidErr('Not a valid UUID or ULID');
  }

  static UuidParseResult _parseUuid(String hex) {
    final String lower = hex.toLowerCase();
    final String canonical =
        '${lower.substring(0, 8)}-${lower.substring(8, 12)}-'
        '${lower.substring(12, 16)}-${lower.substring(16, 20)}-'
        '${lower.substring(20)}';

    final int version = int.parse(lower[12], radix: 16);
    final int variantNibble = int.parse(lower[16], radix: 16);
    final int variant = variantNibble >> 2;

    DateTime? timestamp;
    if (version == 1) {
      timestamp = _timestampV1(lower);
    } else if (version == 7) {
      timestamp = _timestampV7(lower);
    }

    return UuidOk(
      canonical: canonical,
      version: version,
      variant: variant,
      timestamp: timestamp,
    );
  }

  static DateTime _timestampV1(String hex) {
    // v1 timestamp: time_low (8) | time_mid (4) | time_hi_and_version (4)
    // time_hi_and_version has 4 version bits in the top nibble
    final String timeLow = hex.substring(0, 8);
    final String timeMid = hex.substring(8, 12);
    final String timeHi = hex.substring(13, 16); // skip version nibble at [12]

    final int ticks = int.parse('$timeHi$timeMid$timeLow', radix: 16);
    // Gregorian epoch: 1582-10-15T00:00:00Z
    const int gregorianOffset = 122192928000000000; // 100-ns ticks
    final int unixHundredNs = ticks - gregorianOffset;
    final int microseconds = unixHundredNs ~/ 10;
    return DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
  }

  static DateTime _timestampV7(String hex) {
    // High 48 bits = first 12 hex chars = Unix milliseconds
    final int ms = int.parse(hex.substring(0, 12), radix: 16);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static UuidParseResult _parseUlid(String input) {
    final String upper = input.toUpperCase();
    // Decode first 10 Crockford chars → 48-bit timestamp (ms)
    int ms = 0;
    for (int i = 0; i < 10; i++) {
      ms = (ms << 5) | _crockfordDecode(upper.codeUnitAt(i));
    }
    final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
      ms,
      isUtc: true,
    );
    return UlidOk(canonical: upper, timestamp: timestamp);
  }

  static int _crockfordDecode(int codeUnit) {
    // 0-9 → 0-9, A-H → 10-17, J-K → 18-19, M-N → 20-21, P-T → 22-26, V-Z → 27-31
    if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
    // A=65..H=72 → 10..17
    if (codeUnit >= 0x41 && codeUnit <= 0x48) return codeUnit - 0x41 + 10;
    // J=74..K=75 → 18..19
    if (codeUnit >= 0x4A && codeUnit <= 0x4B) return codeUnit - 0x4A + 18;
    // M=77..N=78 → 20..21
    if (codeUnit >= 0x4D && codeUnit <= 0x4E) return codeUnit - 0x4D + 20;
    // P=80..T=84 → 22..26
    if (codeUnit >= 0x50 && codeUnit <= 0x54) return codeUnit - 0x50 + 22;
    // V=86..Z=90 → 27..31
    if (codeUnit >= 0x56 && codeUnit <= 0x5A) return codeUnit - 0x56 + 27;
    return 0;
  }

  static String generateV4({Random? random}) {
    final Random rng = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // Set version 4: byte 6 high nibble = 0100
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Set variant: byte 8 high bits = 10xx
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    return _formatUuid(bytes);
  }

  static String generateV7({DateTime? at, Random? random}) {
    final int ms = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final Random rng = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // High 48 bits = ms timestamp
    bytes[0] = (ms >> 40) & 0xFF;
    bytes[1] = (ms >> 32) & 0xFF;
    bytes[2] = (ms >> 24) & 0xFF;
    bytes[3] = (ms >> 16) & 0xFF;
    bytes[4] = (ms >> 8) & 0xFF;
    bytes[5] = ms & 0xFF;
    // Set version 7: byte 6 high nibble = 0111
    bytes[6] = (bytes[6] & 0x0F) | 0x70;
    // Set variant: byte 8 high bits = 10xx
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    return _formatUuid(bytes);
  }

  static String _formatUuid(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) sb.write('-');
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
