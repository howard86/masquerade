/// Truncates [s] to at most [max] characters, appending a single ellipsis
/// when truncation occurs.
String truncateWithEllipsis(String s, {required int max}) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
