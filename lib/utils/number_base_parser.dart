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

class NumberBaseParser {
  const NumberBaseParser._();

  /// Detects base from prefix or content. Returns null on parse failure.
  static NumberBaseResult? parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    bool negative = false;
    String body = trimmed;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }
    if (body.isEmpty) return null;

    final String lower = body.toLowerCase();
    int? base;
    String digits;

    if (lower.startsWith('0x')) {
      base = 16;
      digits = lower.substring(2);
    } else if (lower.startsWith('0b')) {
      base = 2;
      digits = lower.substring(2);
    } else if (lower.startsWith('0o')) {
      base = 8;
      digits = lower.substring(2);
    } else if (RegExp(r'^[0-9a-f]+$').hasMatch(lower) &&
        RegExp(r'[a-f]').hasMatch(lower)) {
      base = 16;
      digits = lower;
    } else if (RegExp(r'^[01]+$').hasMatch(lower) && lower.length >= 4) {
      // ambiguous; default decimal unless distinctive binary length.
      base = 10;
      digits = lower;
    } else if (RegExp(r'^[0-9]+$').hasMatch(lower)) {
      base = 10;
      digits = lower;
    } else {
      return null;
    }

    digits = digits.replaceAll('_', '');
    if (digits.isEmpty) return null;
    try {
      BigInt parsed = BigInt.parse(digits, radix: base);
      if (negative) parsed = -parsed;
      return NumberBaseResult(value: parsed, detectedBase: base);
    } catch (_) {
      return null;
    }
  }
}
