import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';

double _luminance(Color c) {
  double channel(int c8) {
    final double s = c8 / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).round()) +
      0.7152 * channel((c.g * 255).round()) +
      0.0722 * channel((c.b * 255).round());
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double light = math.max(la, lb);
  final double dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}

/// Composite a tinted-bg pill (foreground status color over its translucent
/// bg, alpha-blended onto the page bg) to verify the visible ink reads
/// against the actually-painted surface, not the raw token.
Color _composite(Color overlay, Color base) {
  final double a = overlay.a;
  if (a >= 0.999) return overlay;
  final double r = overlay.r * a + base.r * (1 - a);
  final double g = overlay.g * a + base.g * (1 - a);
  final double b = overlay.b * a + base.b * (1 - a);
  return Color.fromARGB(
    255,
    (r * 255).round(),
    (g * 255).round(),
    (b * 255).round(),
  );
}

void main() {
  group('MqColors WCAG contrast', () {
    test('light textPri on bg meets AAA (≥7)', () {
      final MqColors c = MqColors.light();
      expect(_contrast(c.textPri, c.bg), greaterThan(7.0));
    });

    test('dark textPri on bg meets AAA (≥7)', () {
      final MqColors c = MqColors.dark();
      expect(_contrast(c.textPri, c.bg), greaterThan(7.0));
    });

    test('textSec on bg meets AA (≥4.5) light', () {
      final MqColors c = MqColors.light();
      expect(_contrast(c.textSec, c.bg), greaterThan(4.5));
    });

    test('textSec on bg meets AA (≥4.5) dark', () {
      final MqColors c = MqColors.dark();
      expect(_contrast(c.textSec, c.bg), greaterThan(4.5));
    });

    test('text hierarchy meets AA on every text surface', () {
      for (final MqColors c in <MqColors>[MqColors.light(), MqColors.dark()]) {
        for (final Color surface in <Color>[
          c.bg,
          c.surface,
          c.surface2,
          c.surface3,
          c.monoBg,
        ]) {
          final double primary = _contrast(c.textPri, surface);
          final double secondary = _contrast(c.textSec, surface);
          final double tertiary = _contrast(c.textTer, surface);
          expect(tertiary, greaterThanOrEqualTo(4.5));
          expect(primary, greaterThan(secondary));
          expect(secondary, greaterThan(tertiary));
        }
      }
    });

    test('accent on bg meets AA (≥4.5) both modes', () {
      expect(
        _contrast(MqColors.light().accent, MqColors.light().bg),
        greaterThan(4.5),
      );
      expect(
        _contrast(MqColors.dark().accent, MqColors.dark().bg),
        greaterThan(4.5),
      );
    });

    test('onTint on accent fill meets AAA (≥7) both modes', () {
      // Filled primary buttons paint the accent at full alpha and the label
      // in onTint — verify the editorial inverse stays readable.
      expect(
        _contrast(MqColors.light().onTint, MqColors.light().accent),
        greaterThan(7.0),
      );
      expect(
        _contrast(MqColors.dark().onTint, MqColors.dark().accent),
        greaterThan(7.0),
      );
    });

    test('status text meets AA on every composited tinted surface', () {
      for (final MqColors c in <MqColors>[MqColors.light(), MqColors.dark()]) {
        for (final Color surface in <Color>[
          c.bg,
          c.surface,
          c.surface2,
          c.surface3,
        ]) {
          expect(
            _contrast(c.success, _composite(c.successBg, surface)),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(c.warning, _composite(c.warningBg, surface)),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(c.danger, _composite(c.dangerBg, surface)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    });

    test('accent cell text meets AA on every composited surface', () {
      for (final MqColors c in <MqColors>[MqColors.light(), MqColors.dark()]) {
        for (final Color surface in <Color>[
          c.bg,
          c.surface,
          c.surface2,
          c.surface3,
        ]) {
          expect(
            _contrast(c.accentInk, _composite(c.accentBg, surface)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    });

    test('mono syntax tokens meet WCAG floor on monoBg', () {
      // monoText is body code — full AAA. Semantic syntax tones carry meaning
      // alongside font weight, so AA (≥4.5) applies to every textual token.
      for (final MqColors c in <MqColors>[MqColors.light(), MqColors.dark()]) {
        expect(_contrast(c.monoText, c.monoBg), greaterThan(7.0));
        expect(_contrast(c.monoString, c.monoBg), greaterThan(4.5));
        expect(_contrast(c.monoKey, c.monoBg), greaterThan(4.5));
        expect(_contrast(c.monoComment, c.monoBg), greaterThan(4.5));
        expect(_contrast(c.monoNumber, c.monoBg), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('MqColors keycap tokens', () {
    test('light exposes the moved keycap hex values', () {
      final MqColors c = MqColors.light();
      expect(c.keycapBg, const Color(0xFFF0F0F3));
      expect(c.keycapBorder, const Color(0xFFD1D1D6));
      expect(c.keycapShadow, const Color(0xFFC0C0C6));
    });

    test('dark exposes the moved keycap hex values', () {
      final MqColors c = MqColors.dark();
      expect(c.keycapBg, const Color(0xFF2A2A2E));
      expect(c.keycapBorder, const Color(0xFF3C3C40));
      expect(c.keycapShadow, const Color(0xFF18181A));
    });
  });

  group('MqColors transparent token', () {
    // mq_button (plain/glass variants) and mq_chip (unemphasized fill) used
    // to inline CupertinoColors.transparent / Color(0x00000000) directly —
    // this token replaces both so the design-system core itself reads colors
    // from MqColors, matching the rule every other tool follows.
    test('light exposes fully transparent', () {
      expect(MqColors.light().transparent, const Color(0x00000000));
    });

    test('dark exposes fully transparent', () {
      expect(MqColors.dark().transparent, const Color(0x00000000));
    });
  });
}
