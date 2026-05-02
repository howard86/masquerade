import 'dart:convert';
import 'dart:typed_data';

sealed class BytesParseResult {
  const BytesParseResult();
}

class BytesParseOk extends BytesParseResult {
  const BytesParseOk(this.bytes);
  final Uint8List bytes;
}

class BytesParseError extends BytesParseResult {
  const BytesParseError(this.message);
  final String message;
}

enum BytesFormat { space, brackets, hex }

class BytesParser {
  const BytesParser._();

  static final RegExp _separator = RegExp(r'[\s,]+');

  /// Parses an integer-list string into bytes.
  ///
  /// Accepts whitespace and/or comma separators, with an optional matching
  /// pair of surrounding `[` / `]`. Each token must parse as an int in 0..255.
  static BytesParseResult parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return const BytesParseError('Empty input');

    String body = trimmed;
    if (body.startsWith('[') && body.endsWith(']')) {
      body = body.substring(1, body.length - 1).trim();
    }

    final List<String> tokens = body
        .split(_separator)
        .where((String t) => t.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return const BytesParseError('No integers found');

    final Uint8List bytes = Uint8List(tokens.length);
    for (int i = 0; i < tokens.length; i++) {
      final String token = tokens[i];
      final int? value = int.tryParse(token);
      if (value == null) {
        return BytesParseError('Invalid integer: $token');
      }
      if (value < 0 || value > 255) {
        return BytesParseError('Byte out of range (0..255): $token');
      }
      bytes[i] = value;
    }
    return BytesParseOk(bytes);
  }

  static Uint8List encodeUtf8(String text) => utf8.encode(text);

  static String format(Uint8List bytes, BytesFormat fmt) {
    switch (fmt) {
      case BytesFormat.space:
        return bytes.join(' ');
      case BytesFormat.brackets:
        return '[${bytes.join(', ')}]';
      case BytesFormat.hex:
        return bytes
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
    }
  }
}
