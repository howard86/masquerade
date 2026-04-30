import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/color_parser.dart';

void main() {
  group('MBColorParser', () {
    test('parses #RRGGBB', () {
      final MBColorValue? v = MBColorParser.parse('#00B8C4');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 184);
      expect(v.b, 196);
      expect(v.a, 1.0);
      expect(v.hex, '#00B8C4');
    });

    test('parses #RGB shorthand', () {
      final MBColorValue? v = MBColorParser.parse('#0BC');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 0xBB);
      expect(v.b, 0xCC);
    });

    test('parses rgb()', () {
      final MBColorValue? v = MBColorParser.parse('rgb(0, 184, 196)');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 184);
      expect(v.b, 196);
    });

    test('parses rgba() with alpha', () {
      final MBColorValue? v = MBColorParser.parse('rgba(255, 0, 0, 0.5)');
      expect(v, isNotNull);
      expect(v!.r, 255);
      expect(v.a, closeTo(0.5, 0.001));
    });

    test('parses hsl()', () {
      final MBColorValue? v = MBColorParser.parse('hsl(184, 100%, 38%)');
      expect(v, isNotNull);
      expect(v!.r, lessThanOrEqualTo(20));
      expect(v.b, greaterThan(150));
    });

    test('contrast ratio calculations match WCAG', () {
      const MBColorValue white = MBColorValue(r: 255, g: 255, b: 255);
      const MBColorValue black = MBColorValue(r: 0, g: 0, b: 0);
      expect(white.contrastRatioAgainst(black), closeTo(21.0, 0.01));
    });

    test('returns null on garbage', () {
      expect(MBColorParser.parse('not a color'), isNull);
      expect(MBColorParser.parse(''), isNull);
    });
  });
}
