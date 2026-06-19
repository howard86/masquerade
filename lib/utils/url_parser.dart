/// Pure URL percent-encoding + query-string parser.
///
/// All entry points are static and return a result struct (an `Ok`/`Error`
/// pair, never a throw) so the body can render an error cell instead of
/// crashing on malformed input. Concern-separated: this is about
/// percent-encoding and `key=value&...` query strings only — not Base64, JSON,
/// or number bases.
library;

/// What [UrlParser.parse] does to its input.
enum UrlMode {
  /// Percent-encode each character that isn't unreserved (`Uri.encodeComponent`
  /// — the safer default for arbitrary text, since it escapes reserved chars
  /// like `&`, `=`, `?`, `/`, `#`).
  encode,

  /// Percent-decode (`Uri.decodeComponent`); `%ZZ` / truncated `%E0` fail.
  decode,
}

/// One ordered `key=value` pair from a query string. Both halves are stored
/// already percent-decoded; either may be empty.
class QueryPair {
  const QueryPair(this.key, this.value);

  final String key;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is QueryPair && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => 'QueryPair($key=$value)';
}

sealed class UrlResult {
  const UrlResult();
}

/// A successful encode/decode plus the parsed query pairs (empty when the input
/// doesn't look like a query string).
class UrlOk extends UrlResult {
  const UrlOk({required this.output, required this.pairs});

  final String output;
  final List<QueryPair> pairs;
}

class UrlError extends UrlResult {
  const UrlError(this.message);

  final String message;
}

class UrlParser {
  const UrlParser._();

  /// Percent-encodes or decodes [input] per [mode]. On decode, a malformed
  /// percent sequence (e.g. `%ZZ`, a truncated `%E0`) returns a [UrlError]
  /// rather than throwing. The returned [UrlOk.pairs] is the input parsed as a
  /// query string (empty when it isn't one).
  static UrlResult parse(String input, {required UrlMode mode}) {
    final List<QueryPair> pairs = splitQuery(input);
    switch (mode) {
      case UrlMode.encode:
        return UrlOk(output: Uri.encodeComponent(input), pairs: pairs);
      case UrlMode.decode:
        try {
          return UrlOk(output: Uri.decodeComponent(input), pairs: pairs);
        } on ArgumentError catch (e) {
          return UrlError('Invalid percent-encoding: ${e.message}');
        } on FormatException catch (e) {
          return UrlError('Invalid percent-encoding: ${e.message}');
        }
    }
  }

  /// Splits a query string into ordered [QueryPair]s, preserving order,
  /// duplicate keys, and empty values. Accepts a bare `a=b&c=d` or a full URL
  /// fragment with a leading `?` (everything before the first `?` is dropped; a
  /// trailing `#fragment` is stripped). Each key and value is percent-decoded;
  /// a half that fails to decode is kept verbatim. Returns empty when there's
  /// no `=` to anchor a pair, so plain text never reads as a query.
  static List<QueryPair> splitQuery(String input) {
    String body = input.trim();
    final int q = body.indexOf('?');
    if (q >= 0) body = body.substring(q + 1);
    final int hash = body.indexOf('#');
    if (hash >= 0) body = body.substring(0, hash);
    if (body.isEmpty || !body.contains('=')) return const <QueryPair>[];

    final List<QueryPair> pairs = <QueryPair>[];
    for (final String segment in body.split('&')) {
      if (segment.isEmpty) continue;
      final int eq = segment.indexOf('=');
      if (eq < 0) {
        pairs.add(QueryPair(_decode(segment), ''));
      } else {
        pairs.add(
          QueryPair(
            _decode(segment.substring(0, eq)),
            _decode(segment.substring(eq + 1)),
          ),
        );
      }
    }
    return pairs;
  }

  /// Rebuilds [pairs] into a canonical `key=value&...` query string, re-encoding
  /// each half so the round-trip through [splitQuery] reproduces the pairs.
  static String buildQuery(List<QueryPair> pairs) => pairs
      .map(
        (QueryPair p) =>
            '${Uri.encodeQueryComponent(p.key)}=${Uri.encodeQueryComponent(p.value)}',
      )
      .join('&');

  /// Percent-decodes a query token, treating `+` as a space (form-encoding) and
  /// falling back to the raw token if the bytes are malformed.
  static String _decode(String token) {
    try {
      return Uri.decodeQueryComponent(token);
    } catch (_) {
      return token;
    }
  }
}
