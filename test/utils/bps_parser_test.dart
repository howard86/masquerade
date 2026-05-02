import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/bps_parser.dart';

void main() {
  group('BpsParser', () {
    test('parses bps suffix', () {
      final BpsResult? r = BpsParser.parse('25 bps');
      expect(r, isNotNull);
      expect(r!.detected, BpsForm.bps);
      expect(r.bps, 25);
      expect(r.percent, closeTo(0.25, 0.0001));
      expect(r.decimal, closeTo(0.0025, 0.000001));
    });

    test('parses percent suffix', () {
      final BpsResult? r = BpsParser.parse('1.5%');
      expect(r, isNotNull);
      expect(r!.detected, BpsForm.percent);
      expect(r.bps, 150);
      expect(r.percent, closeTo(1.5, 0.0001));
    });

    test('detects decimal form for small numbers', () {
      final BpsResult? r = BpsParser.parse('0.05');
      expect(r, isNotNull);
      expect(r!.detected, BpsForm.decimal);
      expect(r.bps, 500);
      expect(r.percent, closeTo(5.0, 0.0001));
    });

    test('detects percent form for >1 numbers', () {
      final BpsResult? r = BpsParser.parse('5');
      expect(r, isNotNull);
      expect(r!.detected, BpsForm.percent);
      expect(r.bps, 500);
    });

    test('returns null on garbage', () {
      expect(BpsParser.parse(''), isNull);
      expect(BpsParser.parse('abc'), isNull);
    });
  });
}
