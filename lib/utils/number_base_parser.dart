/// Parses a numeric token in any base and converts to all four bases.
class NumberBaseResult {
  const NumberBaseResult({required this.value, required this.detectedBase});
  final BigInt value;
  final int detectedBase;

  String get decimal => value.toString();
  String get hex => '0x${value.toRadixString(16).toUpperCase()}';
  String get octal => '0o${value.toRadixString(8)}';
  String get binary => '0b${value.toRadixString(2)}';
}

/// Outcome of [NumberBaseParser.parse]. Mirrors the sealed-result house pattern
/// (see [BytesParseResult]): success carries the value, failure carries a
/// precise, actionable reason instead of a bare `null`.
sealed class NumberBaseParseResult {
  const NumberBaseParseResult();
}

class NumberBaseOk extends NumberBaseParseResult {
  const NumberBaseOk(this.result);
  final NumberBaseResult result;
}

class NumberBaseError extends NumberBaseParseResult {
  const NumberBaseError(this.message);
  final String message;
}

class NumberBaseParser {
  const NumberBaseParser._();

  /// Detects base from prefix or content and converts to all four bases.
  ///
  /// On failure returns a [NumberBaseError] naming the reason — an invalid
  /// digit for the detected base, an empty input, or a prefix with no digits.
  static NumberBaseParseResult parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return const NumberBaseError('Enter a number.');

    bool negative = false;
    String body = trimmed;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }
    if (body.isEmpty) return const NumberBaseError('Enter a number.');

    final String lower = body.toLowerCase();
    int base;
    String digits;
    String label;

    if (lower.startsWith('0x')) {
      base = 16;
      label = 'hexadecimal';
      digits = lower.substring(2);
    } else if (lower.startsWith('0b')) {
      base = 2;
      label = 'binary';
      digits = lower.substring(2);
    } else if (lower.startsWith('0o')) {
      base = 8;
      label = 'octal';
      digits = lower.substring(2);
    } else if (RegExp(r'^[0-9a-f]+$').hasMatch(lower) &&
        RegExp(r'[a-f]').hasMatch(lower)) {
      base = 16;
      label = 'hexadecimal';
      digits = lower;
    } else if (RegExp(r'^[01]+$').hasMatch(lower) && lower.length >= 4) {
      // ambiguous; default decimal unless distinctive binary length.
      base = 10;
      label = 'decimal';
      digits = lower;
    } else if (RegExp(r'^[0-9]+$').hasMatch(lower)) {
      base = 10;
      label = 'decimal';
      digits = lower;
    } else {
      final String bad = _firstInvalidDigit(lower, 10);
      return NumberBaseError(
        bad.isEmpty
            ? '"$body" is not a valid number.'
            : '"$bad" is not a valid digit for a decimal number.',
      );
    }

    final String cleaned = digits.replaceAll('_', '');
    if (cleaned.isEmpty) {
      return NumberBaseError('Enter $label digits after the prefix.');
    }
    final String bad = _firstInvalidDigit(cleaned, base);
    if (bad.isNotEmpty) {
      return NumberBaseError('"$bad" is not a valid $label digit.');
    }

    BigInt parsed = BigInt.parse(cleaned, radix: base);
    if (negative) parsed = -parsed;
    return NumberBaseOk(NumberBaseResult(value: parsed, detectedBase: base));
  }

  /// Returns the first character of [digits] that is not a valid digit in
  /// [radix], or an empty string when every character is valid.
  static String _firstInvalidDigit(String digits, int radix) {
    for (final String ch in digits.split('')) {
      final int? d = int.tryParse(ch, radix: 16);
      if (d == null || d >= radix) return ch;
    }
    return '';
  }
}
