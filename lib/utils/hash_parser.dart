import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'hash_parser_native.dart'
    if (dart.library.js_interop) 'hash_parser_web.dart'
    as platform;

/// Hex SHA-1 / SHA-256 / SHA-512 digests of one input.
typedef ShaDigests = ({String sha1, String sha256, String sha512});

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

  /// SHA-1/256/512 of [bytes]. Synchronous (package:crypto) on native; on web
  /// a Future from `crypto.subtle.digest`, which runs natively instead of
  /// emulating SHA-512's 64-bit arithmetic in JS. Falls back to package:crypto
  /// where SubtleCrypto is missing (insecure context) or rejects.
  static FutureOr<ShaDigests> shaDigests(List<int> bytes) {
    final FutureOr<ShaDigests> Function(List<int>)? override =
        debugShaDigestsOverride;
    if (override != null) return override(bytes);
    final Future<ShaDigests>? native = platform.subtleShaDigests(bytes);
    if (native == null) return shaDigestsSync(bytes);
    return native.catchError((Object _) => shaDigestsSync(bytes));
  }

  static ShaDigests shaDigestsSync(List<int> bytes) => (
    sha1: sha1Hex(bytes),
    sha256: sha256Hex(bytes),
    sha512: sha512Hex(bytes),
  );

  /// Test seam: replaces [shaDigests] (e.g. to simulate slow async digests).
  @visibleForTesting
  static FutureOr<ShaDigests> Function(List<int> bytes)?
  debugShaDigestsOverride;
}
