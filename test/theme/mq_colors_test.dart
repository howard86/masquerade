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
  });
}
