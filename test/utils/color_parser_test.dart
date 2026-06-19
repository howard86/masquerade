import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/color_parser.dart';

void main() {
  group('MqColorParser', () {
    test('parses #RRGGBB', () {
      final MqColorValue? v = MqColorParser.parse('#00B8C4');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 184);
      expect(v.b, 196);
      expect(v.a, 1.0);
      expect(v.hex, '#00B8C4');
    });

    test('parses #RGB shorthand', () {
      final MqColorValue? v = MqColorParser.parse('#0BC');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 0xBB);
      expect(v.b, 0xCC);
    });

    test('parses rgb()', () {
      final MqColorValue? v = MqColorParser.parse('rgb(0, 184, 196)');
      expect(v, isNotNull);
      expect(v!.r, 0);
      expect(v.g, 184);
      expect(v.b, 196);
    });

    test('parses rgba() with alpha', () {
      final MqColorValue? v = MqColorParser.parse('rgba(255, 0, 0, 0.5)');
      expect(v, isNotNull);
      expect(v!.r, 255);
      expect(v.a, closeTo(0.5, 0.001));
    });

    test('parses hsl()', () {
      final MqColorValue? v = MqColorParser.parse('hsl(184, 100%, 38%)');
      expect(v, isNotNull);
      expect(v!.r, lessThanOrEqualTo(20));
      expect(v.b, greaterThan(150));
    });

    test('contrast ratio calculations match WCAG', () {
      const MqColorValue white = MqColorValue(r: 255, g: 255, b: 255);
      const MqColorValue black = MqColorValue(r: 0, g: 0, b: 0);
      expect(white.contrastRatioAgainst(black), closeTo(21.0, 0.01));
    });

    test('returns null on garbage', () {
      expect(MqColorParser.parse('not a color'), isNull);
      expect(MqColorParser.parse(''), isNull);
    });

    test('rejects out-of-range rgb channels instead of clamping', () {
      expect(MqColorParser.parse('rgb(300, 100, 50)'), isNull);
      expect(MqColorParser.parse('rgb(-5, 0, 0)'), isNull);
      expect(MqColorParser.parse('rgb(0, 256, 0)'), isNull);
    });

    test('rejects out-of-range rgba alpha', () {
      expect(MqColorParser.parse('rgba(255, 0, 0, 1.5)'), isNull);
      expect(MqColorParser.parse('rgba(255, 0, 0, -0.1)'), isNull);
    });

    test('still parses in-range rgb', () {
      final MqColorValue? white = MqColorParser.parse('rgb(255, 255, 255)');
      expect(white, isNotNull);
      expect(white!.r, 255);
      expect(white.g, 255);
      expect(white.b, 255);
      final MqColorValue? black = MqColorParser.parse('rgb(0, 0, 0)');
      expect(black, isNotNull);
      expect(black!.r, 0);
      expect(black.g, 0);
      expect(black.b, 0);
    });

    test('rejects out-of-range hsl channels instead of clamping', () {
      expect(MqColorParser.parse('hsl(400, 50%, 50%)'), isNull);
      expect(MqColorParser.parse('hsl(-10, 50%, 50%)'), isNull);
      expect(MqColorParser.parse('hsl(180, 150%, 50%)'), isNull);
      expect(MqColorParser.parse('hsl(180, 50%, 120%)'), isNull);
      expect(MqColorParser.parse('hsla(180, 50%, 50%, 1.5)'), isNull);
    });
  });
}
