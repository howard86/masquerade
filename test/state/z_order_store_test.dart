import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/z_order_store.dart';

void main() {
  test('add puts ids on top; rankOf is back-to-front', () {
    final ZOrderStore s = ZOrderStore()
      ..add(1)
      ..add(2)
      ..add(3);
    expect(s.order, <int>[1, 2, 3]);
    expect(s.top, 3);
    expect(s.rankOf(1), 0);
    expect(s.rankOf(3), 2);
    expect(s.rankOf(9), -1);
  });

  test('raise moves to top and reports change', () {
    final ZOrderStore s = ZOrderStore()
      ..add(1)
      ..add(2)
      ..add(3);
    expect(s.raise(1), isTrue);
    expect(s.order, <int>[2, 3, 1]);
  });

  test('raise is a no-op when already top or unknown', () {
    final ZOrderStore s = ZOrderStore()
      ..add(1)
      ..add(2);
    expect(s.raise(2), isFalse);
    expect(s.raise(7), isFalse);
    expect(s.order, <int>[1, 2]);
  });

  test('remove and restore', () {
    final ZOrderStore s = ZOrderStore()
      ..add(1)
      ..add(2)
      ..add(3);
    s.remove(2);
    expect(s.order, <int>[1, 3]);
    s.restore(<int>[5, 4, 6]);
    expect(s.order, <int>[5, 4, 6]);
    expect(s.top, 6);
    expect(() => s.order.add(1), throwsUnsupportedError);
    s.clear();
    expect(s.top, isNull);
  });
}
