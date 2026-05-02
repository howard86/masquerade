import 'dart:convert';

class JSONParseSuccess {
  const JSONParseSuccess(this.value);
  final Object? value;
}

class JSONParseError {
  const JSONParseError({
    required this.message,
    required this.line,
    required this.column,
  });
  final String message;
  final int line;
  final int column;
}

sealed class JSONParseResult {
  const JSONParseResult();
}

class JSONOk extends JSONParseResult {
  const JSONOk(this.value);
  final JSONParseSuccess value;
}

class JSONErr extends JSONParseResult {
  const JSONErr(this.error);
  final JSONParseError error;
}

class JSONParser {
  const JSONParser._();

  static JSONParseResult parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const JSONErr(
        JSONParseError(message: 'Empty input', line: 1, column: 1),
      );
    }
    try {
      final Object? value = jsonDecode(input);
      return JSONOk(JSONParseSuccess(value));
    } on FormatException catch (e) {
      final int? offset = e.offset;
      final ({int line, int col}) loc = _offsetToLineCol(input, offset ?? 0);
      return JSONErr(
        JSONParseError(message: e.message, line: loc.line, column: loc.col),
      );
    }
  }

  static String pretty(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  static String minify(Object? value) => jsonEncode(value);

  static ({int line, int col}) _offsetToLineCol(String input, int offset) {
    int line = 1;
    int col = 1;
    final int safe = offset.clamp(0, input.length);
    for (int i = 0; i < safe; i++) {
      if (input.codeUnitAt(i) == 0x0A) {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return (line: line, col: col);
  }
}
