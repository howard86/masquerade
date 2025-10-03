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
}
