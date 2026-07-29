/// Truncates [s] to at most [max] characters, appending a single ellipsis
/// when truncation occurs. [max] is clamped to `[0, s.length]` so a
/// negative or overlong value can't throw, and the cut backs off by one
/// code unit if it would split a UTF-16 surrogate pair (e.g. an emoji).
String truncateWithEllipsis(String s, {required int max}) {
  final int clamped = max.clamp(0, s.length);
  if (s.length <= clamped) return s;
  int cut = clamped;
  if (cut > 0) {
    final int prev = s.codeUnitAt(cut - 1);
    final int next = s.codeUnitAt(cut);
    final bool splitsSurrogatePair =
        prev >= 0xD800 && prev <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
    if (splitsSurrogatePair) cut--;
  }
  return '${s.substring(0, cut)}…';
}
