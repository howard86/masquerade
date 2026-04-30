import 'dart:math' as math;
import 'dart:ui' show Color;

class MBColorValue {
  const MBColorValue({
    required this.r,
    required this.g,
    required this.b,
    this.a = 1.0,
  });
  final int r;
  final int g;
  final int b;
  final double a;

  Color get toFlutter =>
      Color.fromARGB((a * 255).round().clamp(0, 255), r, g, b);

  String get hex {
    String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String alpha = a < 1.0 ? h((a * 255).round()) : '';
    return '#${h(r)}${h(g)}${h(b)}$alpha';
  }

  String get rgb {
    if (a < 1.0) {
      return 'rgba($r, $g, $b, ${a.toStringAsFixed(2)})';
    }
    return 'rgb($r, $g, $b)';
  }

  String get hsl {
    final ({double h, double s, double l}) v = _rgbToHsl(r, g, b);
    final String hh = v.h.round().toString();
    final String ss = '${(v.s * 100).round()}%';
    final String ll = '${(v.l * 100).round()}%';
    if (a < 1.0) {
      return 'hsla($hh, $ss, $ll, ${a.toStringAsFixed(2)})';
    }
    return 'hsl($hh, $ss, $ll)';
  }

  String get oklch {
    final ({double l, double c, double h}) v = _rgbToOklch(r, g, b);
    final String ll = v.l.toStringAsFixed(3);
    final String cc = v.c.toStringAsFixed(3);
    final String hh = v.h.toStringAsFixed(1);
    return 'oklch($ll $cc $hh)';
  }

  /// WCAG relative luminance, 0..1.
  double get relativeLuminance {
    double channel(int c8) {
      final double s = c8 / 255.0;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
  }

  double contrastRatioAgainst(MBColorValue other) {
    final double l1 = relativeLuminance;
    final double l2 = other.relativeLuminance;
    final double light = math.max(l1, l2);
    final double dark = math.min(l1, l2);
    return (light + 0.05) / (dark + 0.05);
  }
}

class MBColorParser {
  const MBColorParser._();

  static MBColorValue? parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final MBColorValue? hex = _parseHex(trimmed);
    if (hex != null) return hex;
    final MBColorValue? rgb = _parseRgb(trimmed);
    if (rgb != null) return rgb;
    final MBColorValue? hsl = _parseHsl(trimmed);
    if (hsl != null) return hsl;
    return null;
  }

  static MBColorValue? _parseHex(String input) {
    String s = input;
    if (s.startsWith('#')) s = s.substring(1);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return null;
    if (s.length == 3) {
      s = s.split('').map((String ch) => '$ch$ch').join();
    } else if (s.length == 4) {
      s = s.split('').map((String ch) => '$ch$ch').join();
    }
    if (s.length == 6) {
      return MBColorValue(
        r: int.parse(s.substring(0, 2), radix: 16),
        g: int.parse(s.substring(2, 4), radix: 16),
        b: int.parse(s.substring(4, 6), radix: 16),
      );
    }
    if (s.length == 8) {
      return MBColorValue(
        r: int.parse(s.substring(0, 2), radix: 16),
        g: int.parse(s.substring(2, 4), radix: 16),
        b: int.parse(s.substring(4, 6), radix: 16),
        a: int.parse(s.substring(6, 8), radix: 16) / 255.0,
      );
    }
    return null;
  }

  static MBColorValue? _parseRgb(String input) {
    final RegExp re = RegExp(r'^rgba?\(\s*([^)]+)\)$', caseSensitive: false);
    final RegExpMatch? m = re.firstMatch(input);
    if (m == null) return null;
    final List<String> parts = m.group(1)!.split(RegExp(r'[\s,]+'))
      ..removeWhere((String p) => p.isEmpty);
    if (parts.length < 3) return null;
    final int? r = int.tryParse(parts[0]);
    final int? g = int.tryParse(parts[1]);
    final int? b = int.tryParse(parts[2]);
    if (r == null || g == null || b == null) return null;
    double a = 1.0;
    if (parts.length >= 4) {
      a = double.tryParse(parts[3]) ?? 1.0;
    }
    return MBColorValue(
      r: r.clamp(0, 255),
      g: g.clamp(0, 255),
      b: b.clamp(0, 255),
      a: a.clamp(0.0, 1.0),
    );
  }

  static MBColorValue? _parseHsl(String input) {
    final RegExp re = RegExp(r'^hsla?\(\s*([^)]+)\)$', caseSensitive: false);
    final RegExpMatch? m = re.firstMatch(input);
    if (m == null) return null;
    final List<String> parts = m.group(1)!.split(RegExp(r'[\s,]+'))
      ..removeWhere((String p) => p.isEmpty);
    if (parts.length < 3) return null;
    double? h = double.tryParse(parts[0].replaceAll('deg', ''));
    double? s = double.tryParse(parts[1].replaceAll('%', ''));
    double? l = double.tryParse(parts[2].replaceAll('%', ''));
    if (h == null || s == null || l == null) return null;
    if (parts[1].contains('%')) s /= 100;
    if (parts[2].contains('%')) l /= 100;
    double a = 1.0;
    if (parts.length >= 4) {
      a = double.tryParse(parts[3]) ?? 1.0;
    }
    final ({int r, int g, int b}) rgb = _hslToRgb(
      h,
      s.clamp(0.0, 1.0),
      l.clamp(0.0, 1.0),
    );
    return MBColorValue(r: rgb.r, g: rgb.g, b: rgb.b, a: a.clamp(0.0, 1.0));
  }
}

({double h, double s, double l}) _rgbToHsl(int r, int g, int b) {
  final double rd = r / 255.0;
  final double gd = g / 255.0;
  final double bd = b / 255.0;
  final double maxV = math.max(rd, math.max(gd, bd));
  final double minV = math.min(rd, math.min(gd, bd));
  final double l = (maxV + minV) / 2.0;
  if (maxV == minV) return (h: 0, s: 0, l: l);
  final double d = maxV - minV;
  final double s = l > 0.5 ? d / (2.0 - maxV - minV) : d / (maxV + minV);
  double h;
  if (maxV == rd) {
    h = ((gd - bd) / d + (gd < bd ? 6 : 0));
  } else if (maxV == gd) {
    h = (bd - rd) / d + 2;
  } else {
    h = (rd - gd) / d + 4;
  }
  h *= 60;
  return (h: h, s: s, l: l);
}

({int r, int g, int b}) _hslToRgb(double h, double s, double l) {
  double hueToRgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  if (s == 0) {
    final int v = (l * 255).round();
    return (r: v, g: v, b: v);
  }
  final double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final double p = 2 * l - q;
  final double hk = (h % 360) / 360.0;
  final double r = hueToRgb(p, q, hk + 1 / 3);
  final double g = hueToRgb(p, q, hk);
  final double b = hueToRgb(p, q, hk - 1 / 3);
  return (r: (r * 255).round(), g: (g * 255).round(), b: (b * 255).round());
}

/// sRGB → linear → Oklab → Oklch (per https://bottosson.github.io/posts/oklab/).
({double l, double c, double h}) _rgbToOklch(int r, int g, int b) {
  double srgbToLinear(int c8) {
    final double s = c8 / 255.0;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final double rl = srgbToLinear(r);
  final double gl = srgbToLinear(g);
  final double bl = srgbToLinear(b);

  final double l = 0.4122214708 * rl + 0.5363325363 * gl + 0.0514459929 * bl;
  final double m = 0.2119034982 * rl + 0.6806995451 * gl + 0.1073969566 * bl;
  final double s = 0.0883024619 * rl + 0.2817188376 * gl + 0.6299787005 * bl;

  final double l_ = math.pow(l, 1 / 3) as double;
  final double m_ = math.pow(m, 1 / 3) as double;
  final double s_ = math.pow(s, 1 / 3) as double;

  final double L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
  final double a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
  final double bAxis =
      0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

  final double C = math.sqrt(a * a + bAxis * bAxis);
  double H = math.atan2(bAxis, a) * 180.0 / math.pi;
  if (H < 0) H += 360;
  return (l: L, c: C, h: H);
}
