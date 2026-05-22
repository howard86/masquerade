import 'package:flutter/foundation.dart';

import '../utility_catalog.dart';

/// One open tool instance on the desktop canvas: which tool, where it sits, how
/// wide it is, and the value it was seeded with. Identity is a stable [id] so a
/// card can be moved / resized / duplicated without remounting its tool body.
@immutable
class CanvasCard {
  const CanvasCard({
    required this.id,
    required this.descriptor,
    required this.x,
    required this.y,
    required this.width,
    this.seed,
  });

  final int id;
  final UtilityDescriptor descriptor;
  final double x;
  final double y;
  final double width;

  /// The value the card opened with (paste / pipe). The live, edited value
  /// lives inside the tool body — the controller deliberately doesn't track it
  /// in v1 (that arrives with the link/value channel).
  final String? seed;

  CanvasCard copyWith({double? x, double? y, double? width}) => CanvasCard(
    id: id,
    descriptor: descriptor,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    seed: seed,
  );
}

/// Owns the set of open [CanvasCard]s on the desktop canvas: their positions,
/// widths, which one has focus, and the slot order for ⌥1–9. Pure state — no
/// widgets — so it unit-tests directly. The canvas widget listens and rebuilds.
class CanvasController extends ChangeNotifier {
  CanvasController({double cascadeStep = 32}) : _cascadeStep = cascadeStep;

  /// How far each newly opened card steps down-and-right from the last, so a
  /// burst of opens fans out instead of stacking exactly.
  final double _cascadeStep;

  final List<CanvasCard> _cards = <CanvasCard>[];
  int _nextId = 1;
  int? _focusedId;

  /// Resize bounds for a card's width (logical px).
  static const double minCardWidth = 300;
  static const double maxCardWidth = 880;

  /// Open cards in slot order (the order they were opened). Read-only view.
  List<CanvasCard> get cards => List<CanvasCard>.unmodifiable(_cards);
  bool get isEmpty => _cards.isEmpty;
  int get length => _cards.length;
  int? get focusedId => _focusedId;

  /// The card in 1-based [slot] (⌥1 → slot 1), or null if the slot is empty.
  CanvasCard? cardInSlot(int slot) =>
      (slot >= 1 && slot <= _cards.length) ? _cards[slot - 1] : null;

  /// Opens [descriptor] at the next cascade position, seeded with [seed].
  /// Returns the new card's id and gives it focus. An empty seed is treated as
  /// no seed.
  int openTool(UtilityDescriptor descriptor, {String? seed}) {
    final int step = _cards.length % 5;
    final CanvasCard card = CanvasCard(
      id: _nextId++,
      descriptor: descriptor,
      x: 32 + step * _cascadeStep,
      y: 24 + step * _cascadeStep,
      width: descriptor.defaultCardWidth.px,
      seed: (seed == null || seed.isEmpty) ? null : seed,
    );
    _cards.add(card);
    _focusedId = card.id;
    notifyListeners();
    return card.id;
  }

  /// Closes the card with [id]. Focus falls back to the last remaining card.
  void close(int id) {
    final int before = _cards.length;
    _cards.removeWhere((CanvasCard c) => c.id == id);
    if (_cards.length == before) return;
    if (_focusedId == id) {
      _focusedId = _cards.isEmpty ? null : _cards.last.id;
    }
    notifyListeners();
  }

  /// Closes every card.
  void closeAll() {
    if (_cards.isEmpty) return;
    _cards.clear();
    _focusedId = null;
    notifyListeners();
  }

  /// Gives focus to [id] (no-op if it isn't open or already focused).
  void focus(int id) {
    if (_focusedId == id) return;
    if (!_cards.any((CanvasCard c) => c.id == id)) return;
    _focusedId = id;
    notifyListeners();
  }

  /// Focuses the card in 1-based [slot] (⌥1–9). No-op if the slot is empty.
  void focusSlot(int slot) {
    final CanvasCard? card = cardInSlot(slot);
    if (card != null) focus(card.id);
  }

  /// Moves card [id] to absolute ([x], [y]), clamped to the canvas origin.
  void moveTo(int id, double x, double y) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    _cards[i] = _cards[i].copyWith(x: x < 0 ? 0 : x, y: y < 0 ? 0 : y);
    notifyListeners();
  }

  /// Resizes card [id] to [width], clamped to [minCardWidth]..[maxCardWidth].
  void resize(int id, double width) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final double w = width.clamp(minCardWidth, maxCardWidth);
    if (w == _cards[i].width) return;
    _cards[i] = _cards[i].copyWith(width: w);
    notifyListeners();
  }

  /// Duplicates card [id] — same tool, width, and seed, offset by one cascade
  /// step. Returns the new card's id, or null if [id] isn't open. (v1 freezes
  /// the *seed*; freezing the live edited value arrives with the value channel.)
  int? duplicate(int id) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return null;
    final CanvasCard src = _cards[i];
    final CanvasCard dup = CanvasCard(
      id: _nextId++,
      descriptor: src.descriptor,
      x: src.x + _cascadeStep,
      y: src.y + _cascadeStep,
      width: src.width,
      seed: src.seed,
    );
    _cards.add(dup);
    _focusedId = dup.id;
    notifyListeners();
    return dup.id;
  }
}
