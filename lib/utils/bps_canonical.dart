import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Exact-decimal bridge between bps input text and the live-link canonical (the
/// decimal fraction as a plain string, e.g. `25 bps` -> `0.0025`).
class BpsCanonical {
  const BpsCanonical._();

  static final RegExp _bpsSuffix = RegExp(r'\s*bps?$');
  static final Decimal _tenThousand = Decimal.fromInt(10000);
  static final Decimal _hundred = Decimal.fromInt(100);

  /// The decimal fraction for [input] ("25 bps", "0.25%", "0.0025"), mirroring
  /// `BpsParser`'s form detection. Null when it does not parse.
  static String? decimalOf(String input) {
    String s = input.trim().toLowerCase();
    if (s.endsWith('bps') || s.endsWith('bp')) {
      final Decimal? n = Decimal.tryParse(s.replaceAll(_bpsSuffix, '').trim());
      return n == null ? null : _plain(n / _tenThousand);
    }
    final bool percent = s.endsWith('%');
    if (percent) s = s.substring(0, s.length - 1).trim();
    final Decimal? n = Decimal.tryParse(s);
    if (n == null) return null;
    if (percent || n.abs() > Decimal.one) return _plain(n / _hundred);
    return _plain(n / Decimal.one);
  }

  /// [canonical] (a decimal fraction) as unambiguous bps text, or null when it
  /// is not a decimal number.
  static String? decimalToBpsText(String canonical) {
    final Decimal? n = Decimal.tryParse(canonical.trim());
    return n == null ? null : '${n * _tenThousand} bps';
  }

  static String _plain(Rational r) => r.toDecimal().toString();
}
