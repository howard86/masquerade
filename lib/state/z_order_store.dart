/// Back-to-front stacking order of canvas cards, by card id. The single source
/// of truth for window z-order: the last id is the front-most window.
class ZOrderStore {
  final List<int> _order = <int>[];

  /// Ids from back to front. Read-only view.
  List<int> get order => List<int>.unmodifiable(_order);

  /// The front-most id, or null when empty.
  int? get top => _order.isEmpty ? null : _order.last;

  int get length => _order.length;

  /// Position of [id] from the back (0 = back-most), or -1 if absent.
  int rankOf(int id) => _order.indexOf(id);

  /// Puts [id] on top (moving it if already present).
  void add(int id) {
    _order.remove(id);
    _order.add(id);
  }

  void remove(int id) => _order.remove(id);

  void clear() => _order.clear();

  /// Raises [id] to the front. Returns true if the order changed; false when
  /// [id] is unknown or already on top.
  bool raise(int id) {
    if (_order.isEmpty || _order.last == id) return false;
    if (!_order.remove(id)) return false;
    _order.add(id);
    return true;
  }

  /// Replaces the order with [backToFront] (duplicates keep their first spot).
  void restore(Iterable<int> backToFront) {
    _order
      ..clear()
      ..addAll(backToFront.toSet());
  }
}
