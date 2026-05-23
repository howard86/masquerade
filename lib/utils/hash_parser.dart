import 'package:crypto/crypto.dart';

/// Result of trying to identify a pasted hex string as a known digest shape.
sealed class HashIdentifyResult {}

class HashShape extends HashIdentifyResult {
  HashShape({required this.name, required this.bitLength, required this.hex});
  final String name;
  final int bitLength;
  final String hex;
}

class HashUnknown extends HashIdentifyResult {}

class HashTool {
  const HashTool._();

  static final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

  static const Map<int, (String, int)> _lengthToAlgo = <int, (String, int)>{
    32: ('MD5', 128),
    40: ('SHA-1', 160),
    64: ('SHA-256', 256),
    96: ('SHA-384', 384),
    128: ('SHA-512', 512),
  };

  /// Identifies a hex string as a known digest by length.
  static HashIdentifyResult identify(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty || !_hexPattern.hasMatch(trimmed)) {
      return HashUnknown();
    }
    final (String, int)? match = _lengthToAlgo[trimmed.length];
    if (match == null) return HashUnknown();
    return HashShape(
      name: match.$1,
      bitLength: match.$2,
      hex: trimmed.toLowerCase(),
    );
  }

  static String md5Hex(List<int> bytes) => md5.convert(bytes).toString();

  static String sha1Hex(List<int> bytes) => sha1.convert(bytes).toString();

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  static String sha512Hex(List<int> bytes) => sha512.convert(bytes).toString();
}
