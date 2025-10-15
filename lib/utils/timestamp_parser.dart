import 'encoding_parser.dart';

/// Enum representing different timestamp formats
enum TimestampFormat {
  unixSeconds,
  unixMilliseconds,
  iso8601,
  base64,
  hex,
  unknown,
}

/// Result class for timestamp parsing
class TimestampParseResult {
  const TimestampParseResult({
    required this.timestamp,
    required this.format,
    required this.decoded,
  });

  final DateTime? timestamp;
  final TimestampFormat format;
  final String? decoded;

  /// Returns true if the timestamp was successfully parsed
  bool get isSuccess => timestamp != null;

  /// Returns true if the format is unknown
  bool get isUnknown => format == TimestampFormat.unknown;

  /// Returns true if there's a decoded value
  bool get hasDecoded => decoded != null;
}

/// Utility functions for parsing timestamps from various formats.
class TimestampParser {
  /// Parses a timestamp from various input formats.
  ///
  /// Supports:
  /// - Unix timestamp in seconds (e.g., "1700000000")
  /// - Unix timestamp in milliseconds (e.g., "1700000000000")
  /// - ISO 8601 date strings (e.g., "2023-11-14T22:13:20Z")
  ///
  /// Returns [DateTime] if parsing succeeds, [null] if the input is not a valid timestamp format.
  static DateTime? parseTimestamp(String input) {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return null;
    }

    // Try parsing as Unix timestamp (milliseconds first, then seconds)
    final timestampValue = int.tryParse(trimmedInput);
    if (timestampValue != null) {
      try {
        // Check if it looks like milliseconds (13+ digits or > year 2000 in milliseconds)
        if (timestampValue > 1_000_000_000_000) {
          // Likely milliseconds
          return DateTime.fromMillisecondsSinceEpoch(timestampValue);
        } else {
          // Likely seconds
          return DateTime.fromMillisecondsSinceEpoch(timestampValue * 1000);
        }
      } catch (e) {
        // Invalid timestamp - fall through to try other formats
      }
    }

    // Try parsing as ISO 8601 string
    try {
      return DateTime.parse(trimmedInput);
    } catch (e) {
      // Invalid date string - return null
      return null;
    }
  }

  /// Checks if the input string is a valid timestamp format.
  ///
  /// Returns [true] if the input can be parsed as a timestamp, [false] otherwise.
  static bool isValidTimestamp(String input) {
    return parseTimestamp(input) != null;
  }

  /// Parses encoded input (base64 or hex) and attempts to convert to timestamp.
  ///
  /// Supports:
  /// - Base64 encoded timestamps
  /// - Hex encoded timestamps
  ///
  /// Returns a [TimestampParseResult] with:
  /// - [timestamp]: [DateTime] if parsing succeeds, [null] if not a valid timestamp
  /// - [format]: [TimestampFormat.base64], [TimestampFormat.hex], or [TimestampFormat.unknown]
  /// - [decoded]: the decoded base 10 string, or null if decoding failed
  static TimestampParseResult parseEncodedTimestamp(String input) {
    final encodingResult = EncodingParser.detectAndConvert(input);

    if (encodingResult.isUnknown || encodingResult.isEmpty) {
      return TimestampParseResult(
        timestamp: null,
        format: _encodingTypeToTimestampFormat(encodingResult.type),
        decoded: null,
      );
    }

    final decodedString = encodingResult.result!;
    final timestamp = parseTimestamp(decodedString);

    return TimestampParseResult(
      timestamp: timestamp,
      format: _encodingTypeToTimestampFormat(encodingResult.type),
      decoded: decodedString,
    );
  }

  /// Converts [EncodingType] to [TimestampFormat]
  static TimestampFormat _encodingTypeToTimestampFormat(
    EncodingType encodingType,
  ) {
    switch (encodingType) {
      case EncodingType.base64:
        return TimestampFormat.base64;
      case EncodingType.hex:
        return TimestampFormat.hex;
      case EncodingType.unknown:
        return TimestampFormat.unknown;
    }
  }

  /// Comprehensive parser that handles both direct timestamps and encoded formats.
  ///
  /// Supports:
  /// - Unix timestamp in seconds (e.g., "1700000000")
  /// - Unix timestamp in milliseconds (e.g., "1700000000000")
  /// - ISO 8601 date strings (e.g., "2023-11-14T22:13:20Z")
  /// - Base64 encoded timestamps
  /// - Hex encoded timestamps
  ///
  /// Returns a [TimestampParseResult] with:
  /// - [timestamp]: [DateTime] if parsing succeeds, [null] if not a valid timestamp
  /// - [format]: [TimestampFormat] indicating the detected format
  /// - [decoded]: the decoded string for encoded formats, or null for direct formats
  static TimestampParseResult parseAnyFormat(String input) {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return const TimestampParseResult(
        timestamp: null,
        format: TimestampFormat.unknown,
        decoded: null,
      );
    }

    // First try direct timestamp parsing
    final directTimestamp = parseTimestamp(trimmedInput);
    if (directTimestamp != null) {
      // Determine the format
      TimestampFormat format = TimestampFormat.unknown;
      final timestampValue = int.tryParse(trimmedInput);
      if (timestampValue != null) {
        if (timestampValue > 1_000_000_000_000) {
          format = TimestampFormat.unixMilliseconds;
        } else {
          format = TimestampFormat.unixSeconds;
        }
      } else {
        format = TimestampFormat.iso8601;
      }

      return TimestampParseResult(
        timestamp: directTimestamp,
        format: format,
        decoded: null,
      );
    }

    // Try encoded formats
    final encodedResult = parseEncodedTimestamp(trimmedInput);
    if (encodedResult.isSuccess) {
      return encodedResult;
    }

    // No valid format found
    return const TimestampParseResult(
      timestamp: null,
      format: TimestampFormat.unknown,
      decoded: null,
    );
  }

  /// Checks if the input string is a valid timestamp in any supported format.
  ///
  /// Returns [true] if the input can be parsed as a timestamp in any format, [false] otherwise.
  static bool isValidTimestampAnyFormat(String input) {
    return parseAnyFormat(input).isSuccess;
  }
}
