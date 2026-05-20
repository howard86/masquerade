/// List · split ↔ join. Parses pasted list-like text into a clean item list,
/// then re-joins with a chosen separator and optional per-item transforms.
///
/// One shared [parse] feeds both directions: Split joins the items with a
/// newline, Join joins them with the picked [ListSeparator]. [transform] and
/// [join] are kept separate so the UI can show an exact post-dedupe count.
library;

/// Letter-case applied to every item before dedupe/sort.
enum ListCase { none, upper, lower }

/// Output joiner offered in Join mode. [value] is the literal string used to
/// join items; [label] is the human name shown in the picker sheet.
enum ListSeparator {
  comma(',', 'Comma'),
  commaSpace(', ', 'Comma + space'),
  space(' ', 'Space'),
  newline('\n', 'Newline'),
  semicolon(';', 'Semicolon'),
  pipe('|', 'Pipe'),
  tab('\t', 'Tab');

  const ListSeparator(this.value, this.label);

  final String value;
  final String label;
}

/// Quote character wrapped around each item when quoting is enabled.
enum QuoteStyle {
  doubleQuote('"'),
  singleQuote("'");

  const QuoteStyle(this.char);

  final String char;
}

// Structural delimiters take precedence over whitespace: if any are present we
// split on them only, so multi-word items (e.g. "New York") survive.
final RegExp _structural = RegExp(r'[\n,;|\t]');
final RegExp _whitespace = RegExp(r'\s+');

// Leading list marker: an unordered bullet or an ordered "1." / "1)" marker,
// followed by whitespace or end-of-token. The trailing guard keeps version
// strings like "1.2.3" intact while still dropping a lone "-" (e.g. an empty
// bullet line).
final RegExp _marker = RegExp(r'^([-*+•]|\d+[.)])(\s+|$)');

class ListParser {
  const ListParser._();

  /// Splits [input] into a normalized item list: auto-detects the delimiter,
  /// strips leading list markers, trims, drops blanks, and unwraps surrounding
  /// quotes. Returns an empty list when [input] is blank.
  static List<String> parse(String input) {
    if (input.trim().isEmpty) return const <String>[];
    final List<String> raw = _structural.hasMatch(input)
        ? input.split(_structural)
        : input.split(_whitespace);

    final List<String> items = <String>[];
    for (final String token in raw) {
      String t = token.trim();
      if (t.isEmpty) continue;
      t = t.replaceFirst(_marker, '').trim();
      t = _unquote(t);
      if (t.isEmpty) continue;
      items.add(t);
    }
    return items;
  }

  /// Applies the order-sensitive item transforms: case → dedupe → sort.
  /// Quote-wrapping and bracketing happen later in [join] at output time.
  static List<String> transform(
    List<String> items, {
    ListCase caseMode = ListCase.none,
    bool dedupe = false,
    bool sort = false,
  }) {
    Iterable<String> result = switch (caseMode) {
      ListCase.none => items,
      ListCase.upper => items.map((String e) => e.toUpperCase()),
      ListCase.lower => items.map((String e) => e.toLowerCase()),
    };
    if (dedupe) {
      final Set<String> seen = <String>{};
      result = result.where(seen.add);
    }
    final List<String> out = result.toList();
    if (sort) {
      out.sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
    }
    return out;
  }

  /// Joins [items] with [separator], optionally wrapping each item in
  /// [quoteChar] and the whole result in square brackets.
  static String join(
    List<String> items, {
    required String separator,
    bool quote = false,
    String quoteChar = '"',
    bool bracket = false,
  }) {
    final Iterable<String> parts = quote
        ? items.map((String e) => '$quoteChar$e$quoteChar')
        : items;
    final String joined = parts.join(separator);
    return bracket ? '[$joined]' : joined;
  }

  static String _unquote(String s) {
    if (s.length < 2) return s;
    final String first = s[0];
    final String last = s[s.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }
}
