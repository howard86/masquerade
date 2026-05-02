/// bps · % · decimal — auto-detect input form and convert.
class BpsResult {
  const BpsResult({required this.bps, required this.detected});
  final double bps;
  final BpsForm detected;

  double get percent => bps / 100.0;
  double get decimal => bps / 10000.0;
}

enum BpsForm { bps, percent, decimal }

class BpsParser {
  const BpsParser._();

  static BpsResult? parse(String input) {
    String s = input.trim().toLowerCase();
    if (s.isEmpty) return null;

    BpsForm? form;
    if (s.endsWith('bps') || s.endsWith('bp')) {
      form = BpsForm.bps;
      s = s.replaceAll(RegExp(r'\s*bps?$'), '').trim();
    } else if (s.endsWith('%')) {
      form = BpsForm.percent;
      s = s.substring(0, s.length - 1).trim();
    }
    final double? n = double.tryParse(s);
    if (n == null) return null;

    form ??= n.abs() <= 1.0 ? BpsForm.decimal : BpsForm.percent;

    final double bps = switch (form) {
      BpsForm.bps => n,
      BpsForm.percent => n * 100,
      BpsForm.decimal => n * 10000,
    };
    return BpsResult(bps: bps, detected: form);
  }
}
