import 'dart:convert';

/// Enum representing different encoding types
enum EncodingType { base64, hex, unknown }

/// Result class for encoding detection and conversion
class EncodingResult {
  const EncodingResult({
    required this.type,
    required this.result,
    required this.original,
  });

  final EncodingType type;
  final String? result;
  final String original;

  /// Returns true if the encoding was successfully detected and converted
  bool get isSuccess => type != EncodingType.unknown && result != null;

  /// Returns true if the encoding type is unknown
  bool get isUnknown => type == EncodingType.unknown;

  /// Returns true if the result is null
  bool get isEmpty => result == null;
}

/// Utility functions for detecting and parsing encoded strings.
class EncodingParser {
  /// Detects if a string is base64 encoded.
  ///
  /// Returns [true] if the string appears to be valid base64, [false] otherwise.
  static bool isBase64(String input) {
    final trimmedInput = input.trim();

    // Base64 strings should only contain A-Z, a-z, 0-9, +, /, and = for padding
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');

    if (!base64Regex.hasMatch(trimmedInput)) {
      return false;
    }

    // Check if the length is a multiple of 4 (base64 requirement)
    if (trimmedInput.length % 4 != 0) {
      return false;
    }

    // Try to decode it to see if it's valid base64
    try {
      base64Decode(trimmedInput);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Detects if a string is hexadecimal encoded.
  ///
  /// Returns [true] if the string appears to be valid hex, [false] otherwise.
  static bool isHex(String input) {
    final trimmedInput = input.trim();

    // Remove common hex prefixes
    final cleanInput = trimmedInput
        .replaceFirst(RegExp(r'^0x'), '')
        .replaceFirst(RegExp(r'^#'), '');

    // Hex strings should only contain 0-9 and a-f/A-F
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');

    if (!hexRegex.hasMatch(cleanInput)) {
      return false;
    }

    // Must have even number of characters (each byte is 2 hex chars)
    return cleanInput.length % 2 == 0;
  }

  /// Parses a base64 string and converts it to a base 10 string.
  ///
  /// Returns the decoded string if successful, [null] if parsing fails.
  static String? parseBase64ToBase10(String input) {
    if (!isBase64(input)) {
      return null;
    }

    try {
      final decodedBytes = base64Decode(input.trim());
      return String.fromCharCodes(decodedBytes);
    } catch (e) {
      return null;
    }
  }

  /// Parses a hex string and converts it to a base 10 string.
  ///
  /// Returns the decoded string if successful, [null] if parsing fails.
  static String? parseHexToBase10(String input) {
    if (!isHex(input)) {
      return null;
    }

    try {
      final cleanInput = input
          .trim()
          .replaceFirst(RegExp(r'^0x'), '')
          .replaceFirst(RegExp(r'^#'), '');

      // Convert hex pairs to characters
      final List<int> charCodes = [];
      for (int i = 0; i < cleanInput.length; i += 2) {
        final hexPair = cleanInput.substring(i, i + 2);
        final charCode = int.parse(hexPair, radix: 16);
        charCodes.add(charCode);
      }

      return String.fromCharCodes(charCodes);
    } catch (e) {
      return null;
    }
  }

  /// Automatically detects encoding type and converts to base 10 string.
  ///
  /// Returns an [EncodingResult] with:
  /// - [type]: [EncodingType.base64], [EncodingType.hex], or [EncodingType.unknown]
  /// - [result]: the converted base 10 string, or null if conversion failed
  /// - [original]: the original input string
  static EncodingResult detectAndConvert(String input) {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return const EncodingResult(
        type: EncodingType.unknown,
        result: null,
        original: '',
      );
    }

    // Try hex first (more specific detection)
    if (isHex(trimmedInput)) {
      final result = parseHexToBase10(trimmedInput);
      return EncodingResult(
        type: EncodingType.hex,
        result: result,
        original: trimmedInput,
      );
    }

    // Try base64
    if (isBase64(trimmedInput)) {
      final result = parseBase64ToBase10(trimmedInput);
      return EncodingResult(
        type: EncodingType.base64,
        result: result,
        original: trimmedInput,
      );
    }

    // Unknown format
    return EncodingResult(
      type: EncodingType.unknown,
      result: null,
      original: trimmedInput,
    );
  }

  /// Checks if the input string is a valid encoded format (base64 or hex).
  ///
  /// Returns [true] if the input can be parsed as base64 or hex, [false] otherwise.
  static bool isValidEncodedFormat(String input) {
    return isBase64(input) || isHex(input);
  }
}
