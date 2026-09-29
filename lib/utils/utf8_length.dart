/// UTF-8 byte counts without materializing the encoded bytes.
///
/// Matches `utf8.encode(value).length` exactly, including the 3-byte U+FFFD
/// that `utf8.encode` substitutes for an unpaired surrogate.
library;

/// Whether `utf8.encode(value).length > limit`, skipping the count when the
/// code-unit length alone decides it.
bool utf8LengthExceeds(String value, int limit) {
  // Every code unit encodes to at least 1 byte, and at most 3 (a surrogate
  // pair is 2 units → 4 bytes).
  if (value.length > limit) return true;
  if (value.length * 3 <= limit) return false;
  return utf8Length(value) > limit;
}

/// The number of bytes `utf8.encode(value)` would produce.
int utf8Length(String value) {
  final int length = value.length;
  int bytes = 0;
  for (int i = 0; i < length; i++) {
    final int unit = value.codeUnitAt(i);
    if (unit < 0x80) {
      bytes += 1;
    } else if (unit < 0x800) {
      bytes += 2;
    } else if (unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < length &&
        (value.codeUnitAt(i + 1) & 0xfc00) == 0xdc00) {
      bytes += 4;
      i++;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}
