import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility_catalog.dart';
import 'link_group.dart';

/// Saved geometry before a maximize/snap so the window can restore.
typedef RestoreBounds = ({double x, double y, double width, double? height});

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
    this.z = 0,
    this.minimized = false,
    this.maximized = false,
    this.height,
    this.restoreBounds,
  });

  final int id;
  final UtilityDescriptor descriptor;
  final double x;
  final double y;
  final double width;

  /// Paint order — higher = front.
  final int z;

  /// Whether the card is minimized (hidden from canvas, shown in dock).
  final bool minimized;

  /// Whether the card is maximized (fills the canvas).
  final bool maximized;

  /// Explicit height when maximized/snapped; null = intrinsic.
  final double? height;

  /// Saved pre-maximize/snap geometry for restore.
  final RestoreBounds? restoreBounds;

  /// The value the card opened with (paste / pipe). The live, edited value
  /// lives inside the tool body — the controller deliberately doesn't track it
  /// in v1 (that arrives with the link/value channel).
  final String? seed;

  CanvasCard copyWith({
    double? x,
    double? y,
    double? width,
    int? z,
    bool? minimized,
    bool? maximized,
    double? Function()? height,
    RestoreBounds? Function()? restoreBounds,
  }) => CanvasCard(
    id: id,
    descriptor: descriptor,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    seed: seed,
    z: z ?? this.z,
    minimized: minimized ?? this.minimized,
    maximized: maximized ?? this.maximized,
    height: height != null ? height() : this.height,
    restoreBounds: restoreBounds != null ? restoreBounds() : this.restoreBounds,
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
  int _nextZ = 1;
  int? _focusedId;

  final List<LinkGroup> _groups = <LinkGroup>[];
  int _nextGroupId = 1;

  /// Resize bounds for a card's width (logical px).
  static const double minCardWidth = 300;
  static const double maxCardWidth = 880;

  /// Open cards in slot order (the order they were opened). Read-only view.
  List<CanvasCard> get cards => List<CanvasCard>.unmodifiable(_cards);

  /// Cards sorted by z-order (paint order: lowest first). The canvas paints
  /// in this order so higher-z cards appear on top.
  List<CanvasCard> get cardsByZ =>
      List<CanvasCard>.of(_cards)
        ..sort((CanvasCard a, CanvasCard b) => a.z.compareTo(b.z));

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
      z: _nextZ++,
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
    _detachFromGroup(id);
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
    // Notifiers are dropped, not disposed: the cards' bodies remove their
    // listeners during the ensuing rebuild, after which the notifiers are GC'd.
    _groups.clear();
    _focusedId = null;
    notifyListeners();
    _persist();
  }

  /// Gives focus to [id] (no-op if it isn't open or already focused).
  /// Also raises the card to the front (highest z).
  void focus(int id) {
    if (!_cards.any((CanvasCard c) => c.id == id)) return;
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (_focusedId != id || _cards[i].z != _nextZ - 1) {
      _cards[i] = _cards[i].copyWith(z: _nextZ++);
    }
    if (_focusedId == id) return;
    _focusedId = id;
    notifyListeners();
    _persist();
  }

  /// Focuses the card in 1-based [slot] (⌥1–9). No-op if the slot is empty.
  /// If the card is minimized, restores it first.
  void focusSlot(int slot) {
    final CanvasCard? card = cardInSlot(slot);
    if (card == null) return;
    if (card.minimized) {
      restoreWindow(card.id);
    } else {
      focus(card.id);
    }
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

  /// Minimizes card [id] — hides it from the canvas (shown in dock).
  void minimize(int id) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0 || _cards[i].minimized) return;
    _cards[i] = _cards[i].copyWith(minimized: true);
    if (_focusedId == id) {
      final List<CanvasCard> visible = cardsByZ
          .where((CanvasCard c) => !c.minimized)
          .toList();
      _focusedId = visible.isEmpty ? null : visible.last.id;
    }
    notifyListeners();
    _persist();
  }

  /// Restores a minimized card [id] — shows it on the canvas and focuses it.
  void restoreWindow(int id) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0 || !_cards[i].minimized) return;
    _cards[i] = _cards[i].copyWith(minimized: false, z: _nextZ++);
    _focusedId = id;
    notifyListeners();
    _persist();
  }

  /// Maximizes card [id] to the given fill bounds.
  void maximize(
    int id, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final CanvasCard card = _cards[i];
    final RestoreBounds rb =
        card.restoreBounds ??
        (x: card.x, y: card.y, width: card.width, height: card.height);
    _cards[i] = card.copyWith(
      x: x,
      y: y,
      width: width,
      maximized: true,
      height: () => height,
      restoreBounds: () => rb,
      z: _nextZ++,
    );
    _focusedId = id;
    notifyListeners();
    _persist();
  }

  /// Restores a maximized/snapped card to its saved bounds.
  void unmaximize(int id) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final CanvasCard card = _cards[i];
    final RestoreBounds? rb = card.restoreBounds;
    if (rb == null) return;
    _cards[i] = card.copyWith(
      x: rb.x,
      y: rb.y,
      width: rb.width,
      maximized: false,
      height: () => rb.height,
      restoreBounds: () => null,
    );
    notifyListeners();
    _persist();
  }

  /// Toggles maximize: if maximized/snapped → unmaximize, else maximize.
  void toggleMaximize(
    int id, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    if (_cards[i].maximized || _cards[i].restoreBounds != null) {
      unmaximize(id);
    } else {
      maximize(id, x: x, y: y, width: width, height: height);
    }
  }

  /// Snaps card [id] to arbitrary bounds (half-tile). Saves restoreBounds.
  void snap(
    int id, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final CanvasCard card = _cards[i];
    final RestoreBounds rb =
        card.restoreBounds ??
        (x: card.x, y: card.y, width: card.width, height: card.height);
    _cards[i] = card.copyWith(
      x: x,
      y: y,
      width: width,
      maximized: false,
      height: () => height,
      restoreBounds: () => rb,
      z: _nextZ++,
    );
    _focusedId = id;
    notifyListeners();
    _persist();
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
    'nextGroupId': _nextGroupId,
    'nextZ': _nextZ,
    'focused': _focusedId,
    'cards': _cards
        .map(
          (CanvasCard c) => <String, dynamic>{
            'id': c.id,
            'tool': c.descriptor.id,
            'x': c.x,
            'y': c.y,
            'w': c.width,
            'z': c.z,
            if (c.seed != null) 'seed': c.seed,
            if (c.minimized) 'minimized': true,
            if (c.maximized) 'maximized': true,
            if (c.height != null) 'h': c.height,
            if (c.restoreBounds != null)
              'rb': <String, dynamic>{
                'x': c.restoreBounds!.x,
                'y': c.restoreBounds!.y,
                'w': c.restoreBounds!.width,
                if (c.restoreBounds!.height != null)
                  'h': c.restoreBounds!.height,
              },
          },
        )
        .toList(),
    'groups': _groups
        .map(
          (LinkGroup g) => <String, dynamic>{
            'id': g.id,
            'type': g.type.name,
            'canonical': g.canonical.value,
            'members': g.members.toList(),
          },
        )
        .toList(),
  };

  /// Replaces the canvas from a [toJson] map. Cards whose tool id no longer
  /// exists in the catalog are dropped. Notifies but does not re-persist.
  void applyJson(Map<String, dynamic> json) {
    _cards.clear();
    _groups.clear();
    int maxId = 0;
    int maxZ = 0;
    for (final dynamic raw
        in (json['cards'] as List<dynamic>? ?? const <dynamic>[])) {
      final Map<String, dynamic> m = raw as Map<String, dynamic>;
      final UtilityDescriptor? d = UtilityCatalog.byIdOrNull(
        m['tool'] as String,
      );
      if (d == null) continue;
      final int id = (m['id'] as num).toInt();
      final int z = (m['z'] as num?)?.toInt() ?? id;
      maxId = id > maxId ? id : maxId;
      maxZ = z > maxZ ? z : maxZ;
      RestoreBounds? rb;
      if (m['rb'] is Map<String, dynamic>) {
        final Map<String, dynamic> rbm = m['rb'] as Map<String, dynamic>;
        rb = (
          x: (rbm['x'] as num).toDouble(),
          y: (rbm['y'] as num).toDouble(),
          width: (rbm['w'] as num).toDouble(),
          height: (rbm['h'] as num?)?.toDouble(),
        );
      }
      _cards.add(
        CanvasCard(
          id: id,
          descriptor: d,
          x: (m['x'] as num).toDouble(),
          y: (m['y'] as num).toDouble(),
          width: (m['w'] as num).toDouble(),
          seed: m['seed'] as String?,
          z: z,
          minimized: m['minimized'] as bool? ?? false,
          maximized: m['maximized'] as bool? ?? false,
          height: (m['h'] as num?)?.toDouble(),
          restoreBounds: rb,
        ),
      );
    }
    _nextId = (json['nextId'] as num?)?.toInt() ?? (maxId + 1);
    if (_nextId <= maxId) _nextId = maxId + 1;
    _nextZ = (json['nextZ'] as num?)?.toInt() ?? (maxZ + 1);
    if (_nextZ <= maxZ) _nextZ = maxZ + 1;
    final int? focused = (json['focused'] as num?)?.toInt();
    _focusedId = _cards.any((CanvasCard c) => c.id == focused) ? focused : null;

    int maxGid = 0;
    for (final dynamic raw
        in (json['groups'] as List<dynamic>? ?? const <dynamic>[])) {
      final Map<String, dynamic> m = raw as Map<String, dynamic>;
      final ContentType? type = _contentTypeOrNull(m['type'] as String?);
      if (type == null) continue;
      final Set<int> members = (m['members'] as List<dynamic>)
          .map((dynamic e) => (e as num).toInt())
          .where((int cid) => _cards.any((CanvasCard c) => c.id == cid))
          .toSet();
      if (members.length < 2) continue; // a link needs at least two live cards
      final int gid = (m['id'] as num).toInt();
      maxGid = gid > maxGid ? gid : maxGid;
      _groups.add(
        LinkGroup(
          id: gid,
          type: type,
          canonical: m['canonical'] as String? ?? '',
        )..members.addAll(members),
      );
    }
    _nextGroupId = (json['nextGroupId'] as num?)?.toInt() ?? (maxGid + 1);
    if (_nextGroupId <= maxGid) _nextGroupId = maxGid + 1;

    notifyListeners();
  }

  static ContentType? _contentTypeOrNull(String? name) {
    for (final ContentType t in ContentType.values) {
      if (t.name == name) return t;
    }
    return null;
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

  // ─── Live links (canonical-hub, see docs/adr/0001) ──────────────────────

  /// All link groups (read-only). The canvas draws a gold line per group.
  List<LinkGroup> get groups => List<LinkGroup>.unmodifiable(_groups);

  bool get hasLinks => _groups.isNotEmpty;

  /// The link group [cardId] belongs to, or null if it isn't linked.
  LinkGroup? groupForCard(int cardId) {
    for (final LinkGroup g in _groups) {
      if (g.members.contains(cardId)) return g;
    }
    return null;
  }

  /// A [LinkChannel] for [cardId] when it's linked, else null. The canvas hands
  /// this to the tool body via the builder's `link` parameter.
  LinkChannel? channelForCard(int cardId) {
    final LinkGroup? g = groupForCard(cardId);
    if (g == null) return null;
    return LinkChannel(
      canonicalType: g.type,
      inbound: g.canonical,
      onEmit: (String value) => _emit(g, value),
    );
  }

  /// Links [a] and [b] into a shared group of [type]. If either is already in a
  /// group, the other joins it; otherwise a new group is created seeded with
  /// [seedCanonical]. Returns the group id. A card lives in at most one group.
  int linkCards(
    int a,
    int b, {
    required ContentType type,
    String seedCanonical = '',
  }) {
    LinkGroup g =
        groupForCard(a) ??
        groupForCard(b) ??
        (LinkGroup(id: _nextGroupId++, type: type, canonical: seedCanonical)
          ..canonical.value = seedCanonical);
    if (!_groups.contains(g)) _groups.add(g);
    g.members
      ..add(a)
      ..add(b);
    notifyListeners();
    _persist();
    return g.id;
  }

  /// Removes [cardId] from its group, dissolving the group when fewer than two
  /// members remain.
  void unlinkCard(int cardId) {
    if (_detachFromGroup(cardId)) {
      notifyListeners();
      _persist();
    }
  }

  bool _detachFromGroup(int cardId) {
    final LinkGroup? g = groupForCard(cardId);
    if (g == null) return false;
    g.members.remove(cardId);
    if (g.members.length < 2) _groups.remove(g);
    return true;
  }

  void _emit(LinkGroup g, String value) {
    if (!_groups.contains(g)) return;
    if (g.canonical.value == value) return; // idempotent → cycles terminate
    g.canonical.value = value;
    _persist();
  }
}
