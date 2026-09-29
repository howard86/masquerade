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
        return _decimal(bytes, ' ');
      case BytesFormat.brackets:
        return '[${_decimal(bytes, ', ')}]';
      case BytesFormat.hex:
        return _hex(bytes);
    }
  }

  static const String _hexDigits = '0123456789abcdef';

  /// Lower-case two-digit hex, space separated, written straight into an
  /// ASCII code-unit buffer.
  static String _hex(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final Uint8List out = Uint8List(bytes.length * 3 - 1);
    int o = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (i > 0) out[o++] = 0x20;
      final int byte = bytes[i];
      out[o++] = _hexDigits.codeUnitAt(byte >> 4);
      out[o++] = _hexDigits.codeUnitAt(byte & 0x0f);
    }
    return String.fromCharCodes(out);
  }

  /// Decimal byte values joined by [separator] (ASCII), without a string
  /// per byte.
  static String _decimal(Uint8List bytes, String separator) {
    if (bytes.isEmpty) return '';
    final Uint8List out = Uint8List(
      bytes.length * (3 + separator.length) - separator.length,
    );
    int o = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (i > 0) {
        for (int s = 0; s < separator.length; s++) {
          out[o++] = separator.codeUnitAt(s);
        }
      }
      final int byte = bytes[i];
      if (byte >= 100) out[o++] = 0x30 + byte ~/ 100;
      if (byte >= 10) out[o++] = 0x30 + byte ~/ 10 % 10;
      out[o++] = 0x30 + byte % 10;
    }
    return String.fromCharCodes(out, 0, o);
  }
}
