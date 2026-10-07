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
    this.fixable = false,
    this.fixedText,
  });
  final String message;
  final int line;
  final int column;

  /// True when [JSONParser] can offer a one-tap fix; [fixedText] is the
  /// edited input that should re-parse cleanly.
  final bool fixable;
  final String? fixedText;
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

  /// Parses [input]. When [suggestFix] is false the one-tap auto-fix probe
  /// (which rebuilds and re-decodes the whole input) is skipped, so a
  /// [JSONErr] never carries a [JSONParseError.fixedText]. Detection only
  /// needs success/failure and passes false.
  static JSONParseResult parse(String input, {bool suggestFix = true}) {
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
      final int offset = e.offset ?? 0;
      final ({int line, int col}) loc = _offsetToLineCol(input, offset);
      final String? fixed = suggestFix
          ? _tryAutoFix(input, offset, e.message)
          : null;
      return JSONErr(
        JSONParseError(
          message: e.message,
          line: loc.line,
          column: loc.col,
          fixable: fixed != null,
          fixedText: fixed,
        ),
      );
    }
  }

  /// Returns an edited [input] that should re-parse cleanly, or null when
  /// the error is not one of the supported fixable cases:
  ///   - trailing comma before a closing `}` or `]`
  ///   - unterminated string at end of input
  static String? _tryAutoFix(String input, int offset, String message) {
    final String? trailing = _fixTrailingComma(input);
    if (trailing != null) return trailing;
    final String? eofString = _fixUnterminatedStringAtEof(input, message);
    if (eofString != null) return eofString;
    return null;
  }

  /// Removes any single `,` that is followed (after whitespace) by `}` or `]`.
  /// Only operates outside string literals. Returns null when no trailing
  /// comma exists or when the resulting text still fails to parse.
  static String? _fixTrailingComma(String input) {
    final StringBuffer out = StringBuffer();
    bool inString = false;
    bool escaped = false;
    bool changed = false;
    for (int i = 0; i < input.length; i++) {
      final int ch = input.codeUnitAt(i);
      if (inString) {
        out.writeCharCode(ch);
        if (escaped) {
          escaped = false;
        } else if (ch == 0x5C) {
          escaped = true;
        } else if (ch == 0x22) {
          inString = false;
        }
        continue;
      }
      if (ch == 0x22) {
        inString = true;
        out.writeCharCode(ch);
        continue;
      }
      if (ch == 0x2C) {
        int j = i + 1;
        while (j < input.length && _isJsonWhitespace(input.codeUnitAt(j))) {
          j++;
        }
        if (j < input.length) {
          final int next = input.codeUnitAt(j);
          if (next == 0x7D || next == 0x5D) {
            changed = true;
            continue;
          }
        }
      }
      out.writeCharCode(ch);
    }
    if (!changed) return null;
    final String candidate = out.toString();
    try {
      jsonDecode(candidate);
      return candidate;
    } on FormatException {
      return null;
    }
  }

  /// Appends a closing `"` plus any outstanding `}` / `]` when the parser
  /// bailed on an unterminated string at EOF. Returns null otherwise.
  static String? _fixUnterminatedStringAtEof(String input, String message) {
    if (!message.toLowerCase().contains('unterminated string')) return null;
    final List<int> stack = <int>[];
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < input.length; i++) {
      final int ch = input.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == 0x5C) {
          escaped = true;
        } else if (ch == 0x22) {
          inString = false;
        }
        continue;
      }
      if (ch == 0x22) {
        inString = true;
      } else if (ch == 0x7B) {
        stack.add(0x7D);
      } else if (ch == 0x5B) {
        stack.add(0x5D);
      } else if (ch == 0x7D || ch == 0x5D) {
        if (stack.isNotEmpty && stack.last == ch) stack.removeLast();
      }
    }
    if (!inString) return null;
    final StringBuffer fixed = StringBuffer(input);
    fixed.write('"');
    for (int i = stack.length - 1; i >= 0; i--) {
      fixed.writeCharCode(stack[i]);
    }
    final String candidate = fixed.toString();
    try {
      jsonDecode(candidate);
      return candidate;
    } on FormatException {
      return null;
    }
  }

  static bool _isJsonWhitespace(int ch) =>
      ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D;

  static String pretty(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  static String minify(Object? value) => jsonEncode(value);

  /// Indented key-path renderer used by the JSON tool's "Tree" view. Sits
  /// next to [pretty] / [minify] so callers can dispatch by enum without
  /// leaving the parser layer.
  static String tree(Object? value) {
    final StringBuffer out = StringBuffer();
    _renderTree(out, value, 0);
    return out.toString();
  }

  /// Writes the same text the old per-level `lines.join('\n')` renderer
  /// produced, into one shared buffer so each node is copied once instead of
  /// once per ancestor.
  static void _renderTree(StringBuffer out, Object? v, int depth) {
    final String indent = '  ' * depth;
    if (v is Map) {
      if (v.isEmpty) {
        out.write('{}');
        return;
      }
      out.write('{');
      v.forEach((Object? k, Object? val) {
        out.write('\n$indent  $k: ');
        _renderTree(out, val, depth + 1);
      });
      out.write('\n$indent}');
      return;
    }
    if (v is List) {
      if (v.isEmpty) {
        out.write('[]');
        return;
      }
      out.write('[');
      for (int i = 0; i < v.length; i++) {
        out.write('\n$indent  [$i] ');
        _renderTree(out, v[i], depth + 1);
      }
      out.write('\n$indent]');
      return;
    }
    out.write('$v');
  }

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
