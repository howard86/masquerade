import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/bps_canonical.dart';

void main() {
  test('decimalOf maps each form to the exact decimal fraction', () {
    expect(BpsCanonical.decimalOf('25 bps'), '0.0025');
    expect(BpsCanonical.decimalOf('1.5%'), '0.015');
    expect(BpsCanonical.decimalOf('0.0025'), '0.0025');
    expect(BpsCanonical.decimalOf('50'), '0.5');
    expect(BpsCanonical.decimalOf('abc'), isNull);
  });

  test('decimalToBpsText round-trips through decimalOf', () {
    for (final String d in <String>['0.0025', '2', '0.1234', '0']) {
      expect(
        BpsCanonical.decimalOf(BpsCanonical.decimalToBpsText(d)!),
        d,
        reason: d,
      );
    }
    expect(BpsCanonical.decimalToBpsText('x'), isNull);
  });
}
