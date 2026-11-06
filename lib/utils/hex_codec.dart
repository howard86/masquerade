import 'dart:typed_data';

/// Lowercase, separator-free hex — the canonical form of a `bytes` link group.
class HexCodec {
  const HexCodec._();

  static const String _digits = '0123456789abcdef';

  /// `[0x48, 0x69]` → `'4869'`; empty bytes → `''`.
  static String encode(List<int> bytes) {
    final StringBuffer out = StringBuffer();
    for (final int b in bytes) {
      out
        ..write(_digits[(b >> 4) & 0xf])
        ..write(_digits[b & 0xf]);
    }
    return out.toString();
  }

  /// Parses even-length hex (any case); null when [hex] is malformed. The
  /// empty string decodes to zero bytes.
  static Uint8List? decode(String hex) {
    if (hex.length.isOdd) return null;
    final Uint8List out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      final int? v = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (v == null) return null;
      out[i] = v;
    }
    return out;
  }
}
