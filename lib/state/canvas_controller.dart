import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  CanvasController({double cascadeStep = 32, SharedPreferences? prefs})
    : _cascadeStep = cascadeStep,
      _prefs = prefs;

  /// How far each newly opened card steps down-and-right from the last, so a
  /// burst of opens fans out instead of stacking exactly.
  final double _cascadeStep;

  /// Persistence backend. Null in unit tests and until [attachPrefs] runs — the
  /// controller is purely in-memory then.
  SharedPreferences? _prefs;

  /// Key for the auto-restored "current canvas" snapshot.
  static const String currentKey = 'mb.canvas.current';

  /// Key for the map of named saved layouts (`{name: canvasJson}`).
  static const String layoutsKey = 'mb.canvas.layouts';

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
    _persist();
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
    _persist();
  }

  /// Closes every card.
  void closeAll() {
    if (_cards.isEmpty) return;
    _cards.clear();
    _focusedId = null;
    notifyListeners();
    _persist();
  }

  /// Gives focus to [id] (no-op if it isn't open or already focused).
  void focus(int id) {
    if (_focusedId == id) return;
    if (!_cards.any((CanvasCard c) => c.id == id)) return;
    _focusedId = id;
    notifyListeners();
    _persist();
  }

  /// Focuses the card in 1-based [slot] (⌥1–9). No-op if the slot is empty.
  void focusSlot(int slot) {
    final CanvasCard? card = cardInSlot(slot);
    if (card != null) focus(card.id);
  }

  /// Moves card [id] to absolute ([x], [y]), clamped to the canvas origin.
  /// Does not persist per-tick — call [commit] when the drag ends.
  void moveTo(int id, double x, double y) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    _cards[i] = _cards[i].copyWith(x: x < 0 ? 0 : x, y: y < 0 ? 0 : y);
    notifyListeners();
  }

  /// Resizes card [id] to [width], clamped to [minCardWidth]..[maxCardWidth].
  /// Does not persist per-tick — call [commit] when the drag ends.
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
    _persist();
    return dup.id;
  }

  /// Persists the current canvas — call after a drag (move/resize) settles.
  void commit() => _persist();

  // ─── Persistence ──────────────────────────────────────────────────────────

  /// Attaches a prefs backend after its async load and restores the last
  /// auto-saved canvas. Called once by the desktop shell on startup.
  void attachPrefs(SharedPreferences prefs) {
    _prefs = prefs;
    restore();
  }

  /// Serializes the open cards for persistence. Card ids are kept so focus and
  /// (later) link membership survive a reload.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'nextId': _nextId,
    'focused': _focusedId,
    'cards': _cards
        .map(
          (CanvasCard c) => <String, dynamic>{
            'id': c.id,
            'tool': c.descriptor.id,
            'x': c.x,
            'y': c.y,
            'w': c.width,
            if (c.seed != null) 'seed': c.seed,
          },
        )
        .toList(),
  };

  /// Replaces the canvas from a [toJson] map. Cards whose tool id no longer
  /// exists in the catalog are dropped. Notifies but does not re-persist.
  void applyJson(Map<String, dynamic> json) {
    _cards.clear();
    int maxId = 0;
    for (final dynamic raw
        in (json['cards'] as List<dynamic>? ?? const <dynamic>[])) {
      final Map<String, dynamic> m = raw as Map<String, dynamic>;
      final UtilityDescriptor? d = UtilityCatalog.byIdOrNull(
        m['tool'] as String,
      );
      if (d == null) continue;
      final int id = (m['id'] as num).toInt();
      maxId = id > maxId ? id : maxId;
      _cards.add(
        CanvasCard(
          id: id,
          descriptor: d,
          x: (m['x'] as num).toDouble(),
          y: (m['y'] as num).toDouble(),
          width: (m['w'] as num).toDouble(),
          seed: m['seed'] as String?,
        ),
      );
    }
    _nextId = (json['nextId'] as num?)?.toInt() ?? (maxId + 1);
    if (_nextId <= maxId) _nextId = maxId + 1;
    final int? focused = (json['focused'] as num?)?.toInt();
    _focusedId = _cards.any((CanvasCard c) => c.id == focused) ? focused : null;
    notifyListeners();
  }

  /// Restores the auto-saved canvas from prefs. No-op without a backend or
  /// when the stored snapshot is missing or corrupt.
  void restore() {
    final String? raw = _prefs?.getString(currentKey);
    if (raw == null) return;
    try {
      applyJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt snapshot — start clean rather than crash.
    }
  }

  void _persist() {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString(currentKey, jsonEncode(toJson())));
  }

  // ─── Named saved layouts ────────────────────────────────────────────────

  Map<String, dynamic> _layouts() {
    final String? raw = _prefs?.getString(layoutsKey);
    if (raw == null) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Names of saved layouts, alphabetically.
  List<String> get layoutNames => _layouts().keys.toList()..sort();

  /// Saves the current canvas under [name] (overwriting any same-named layout).
  void saveLayout(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || _prefs == null) return;
    final Map<String, dynamic> all = _layouts()..[trimmed] = toJson();
    unawaited(_prefs!.setString(layoutsKey, jsonEncode(all)));
  }

  /// Loads the layout named [name] onto the canvas, if it exists.
  void restoreLayout(String name) {
    final Map<String, dynamic> all = _layouts();
    final dynamic snapshot = all[name];
    if (snapshot is Map<String, dynamic>) {
      applyJson(snapshot);
      _persist();
    }
  }

  /// Deletes the layout named [name].
  void deleteLayout(String name) {
    if (_prefs == null) return;
    final Map<String, dynamic> all = _layouts()..remove(name);
    unawaited(_prefs!.setString(layoutsKey, jsonEncode(all)));
  }
}
