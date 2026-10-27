import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility_catalog.dart';
import '../utils/sensitive_data_policy.dart';
import 'link_group.dart';
import 'window_content.dart';

/// Saved geometry before a maximize/snap so the window can restore.
typedef RestoreBounds = ({double x, double y, double width, double? height});

/// One open tool instance on the desktop canvas: which tool, where it sits, how
/// wide it is, and the value it was seeded with. Identity is a stable [id] so a
/// card can be moved / resized / duplicated without remounting its tool body.
@immutable
class CanvasCard {
  const CanvasCard({
    required this.id,
    required this.content,
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
  final WindowContent content;
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

  /// Convenience: the underlying [UtilityDescriptor] when this card holds a
  /// tool, or null for system windows.
  UtilityDescriptor? get toolDescriptor =>
      content is ToolWindow ? (content as ToolWindow).descriptor : null;

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
    content: content,
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
/// widgets — so it unit-tests directly.
///
/// Two change signals, so a drag doesn't rebuild the whole desktop:
///  * the controller itself ([addListener]) fires on *structural* changes —
///    open / close / minimize / maximize / snap / focus / z / links / restore —
///    which the canvas, menubar and dock listen to;
///  * geometry-only ticks ([moveTo], [resize], [resizeEdge]) fire only
///    [geometry] plus the moved card's [watchCard] listenable, which the
///    card's own positioned wrapper listens to.
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

  final _Signal _geometry = _Signal();
  final Map<int, ValueNotifier<CanvasCard>> _watchers =
      <int, ValueNotifier<CanvasCard>>{};

  /// Fires on every geometry-only change (a move / resize tick) of any card.
  /// Structural changes fire the controller itself instead.
  Listenable get geometry => _geometry;

  /// A listenable holding card [id]'s latest record; it fires whenever that
  /// card changes (geometry ticks included). [id] must be open.
  ValueListenable<CanvasCard> watchCard(int id) => _watchers.putIfAbsent(
    id,
    () => ValueNotifier<CanvasCard>(
      _cards.firstWhere((CanvasCard c) => c.id == id),
    ),
  );

  /// Replaces `_cards[i]` and pushes it to that card's [watchCard] listeners.
  void _replace(int i, CanvasCard next) {
    _cards[i] = next;
    _watchers[next.id]?.value = next;
  }

  /// Drops watchers of closed cards and resyncs the rest after a bulk change.
  void _syncWatchers() {
    if (_watchers.isEmpty) return;
    final Map<int, CanvasCard> byId = <int, CanvasCard>{
      for (final CanvasCard c in _cards) c.id: c,
    };
    _watchers.removeWhere((int id, ValueNotifier<CanvasCard> n) {
      final CanvasCard? card = byId[id];
      if (card == null) return true;
      n.value = card;
      return false;
    });
  }

  /// Resize bounds for a card's width (logical px).
  static const double minCardWidth = 300;
  static const double maxCardWidth = 880;
  static const double minCardHeight = 150;
  static const double maxCardHeight = 1000;

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
      content: ToolWindow(descriptor),
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

  /// Opens a system window (History / Settings). Deduplicates: if already open,
  /// restores (if minimized) and focuses it. Returns the card id.
  int openSystem(SystemApp app) {
    final WindowContent target = SystemWindow(app);
    final int existing = _cards.indexWhere(
      (CanvasCard c) =>
          c.content is SystemWindow && (c.content as SystemWindow).app == app,
    );
    if (existing >= 0) {
      final int id = _cards[existing].id;
      if (_cards[existing].minimized) {
        restoreWindow(id);
      } else {
        focus(id);
      }
      return id;
    }
    final int step = _cards.length % 5;
    final CanvasCard card = CanvasCard(
      id: _nextId++,
      content: target,
      x: 32 + step * _cascadeStep,
      y: 24 + step * _cascadeStep,
      width: 440,
      height: 600,
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
    _watchers.remove(id);
    _persistedSeeds.remove(id);
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
    _watchers.clear();
    _persistedSeeds.clear();
    _persistedCanonicals.clear();
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
      _replace(i, _cards[i].copyWith(z: _nextZ++));
    }
    if (_focusedId == id) return;
    _focusedId = id;
    notifyListeners();
    // Focus clicks are frequent and only change focus / z: coalesce them.
    _schedulePersist();
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
  /// Allows small negative Y values so the window can go partially off-screen at
  /// the top, but the title bar remains grabbable.
  /// Does not persist per-tick — call [commit] when the drag ends.
  void moveTo(int id, double x, double y) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    _replace(i, _cards[i].copyWith(x: x, y: y < -20 ? -20 : y));
    _geometry.fire();
  }

  /// Moves card [id] relative to its latest position.
  void moveBy(int id, double dx, double dy) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    moveTo(id, _cards[i].x + dx, _cards[i].y + dy);
  }

  /// Resizes card [id] to [width], clamped to [minCardWidth]..[maxCardWidth].
  /// Does not persist per-tick — call [commit] when the drag ends.
  void resize(int id, double width) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final double w = width.clamp(minCardWidth, maxCardWidth);
    if (w == _cards[i].width) return;
    _replace(i, _cards[i].copyWith(width: w));
    _geometry.fire();
  }

  /// Directionally resizes card [id] by [dx] and [dy] relative to the active edges.
  /// If the card's current height is null, [measuredHeight] is used as the base height.
  /// Does not persist per-tick — call [commit] when the drag ends.
  void resizeEdge(
    int id, {
    required double dx,
    required double dy,
    required bool left,
    required bool right,
    required bool top,
    required bool bottom,
    required double measuredHeight,
  }) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return;
    final CanvasCard card = _cards[i];

    double nextX = card.x;
    double nextW = card.width;
    double nextY = card.y;
    double nextH = card.height ?? measuredHeight;

    if (left) {
      final double preferredW = nextW - dx;
      final double clampedW = preferredW.clamp(minCardWidth, maxCardWidth);
      final double actualDw = clampedW - nextW;
      nextW = clampedW;
      nextX = nextX - actualDw;
    } else if (right) {
      nextW = (nextW + dx).clamp(minCardWidth, maxCardWidth);
    }

    if (top) {
      final double preferredH = nextH - dy;
      final double clampedH = preferredH.clamp(minCardHeight, maxCardHeight);
      final double actualDh = clampedH - nextH;
      nextH = clampedH;
      nextY = nextY - actualDh;
    } else if (bottom) {
      nextH = (nextH + dy).clamp(minCardHeight, maxCardHeight);
    }

    _replace(
      i,
      card.copyWith(x: nextX, y: nextY, width: nextW, height: () => nextH),
    );
    _geometry.fire();
  }

  /// Duplicates card [id] — same tool, width, and seed, offset by one cascade
  /// step. Returns the new card's id, or null if [id] isn't open or is a system
  /// window (system windows are singletons).
  int? duplicate(int id) {
    final int i = _cards.indexWhere((CanvasCard c) => c.id == id);
    if (i < 0) return null;
    final CanvasCard src = _cards[i];
    if (src.content is SystemWindow) return null;
    final CanvasCard dup = CanvasCard(
      id: _nextId++,
      content: src.content,
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
    _replace(i, _cards[i].copyWith(minimized: true));
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
    _replace(i, _cards[i].copyWith(minimized: false, z: _nextZ++));
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
    _replace(
      i,
      card.copyWith(
        x: x,
        y: y,
        width: width,
        maximized: true,
        height: () => height,
        restoreBounds: () => rb,
        z: _nextZ++,
      ),
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
    _replace(
      i,
      card.copyWith(
        x: rb.x,
        y: rb.y,
        width: rb.width,
        maximized: false,
        height: () => rb.height,
        restoreBounds: () => null,
      ),
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
    _replace(
      i,
      card.copyWith(
        x: x,
        y: y,
        width: width,
        maximized: false,
        height: () => height,
        restoreBounds: () => rb,
        z: _nextZ++,
      ),
    );
    _focusedId = id;
    notifyListeners();
    _persist();
  }

  /// Persists the current canvas — call after a drag (move/resize) settles.
  void commit() => _persist();

  @override
  void dispose() {
    flushPersist();
    _geometry.dispose();
    super.dispose();
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  /// Attaches a prefs backend after its async load and restores the last
  /// auto-saved canvas. Called once by the desktop shell on startup.
  void attachPrefs(SharedPreferences prefs) {
    _prefs = prefs;
    restore();
    unawaited(_sanitizePersistedLayouts(prefs));
  }

  /// Serializes the open cards for persistence. Card ids are kept so focus and
  /// (later) link membership survive a reload.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'nextId': _nextId,
    'nextGroupId': _nextGroupId,
    'nextZ': _nextZ,
    'focused': _focusedId,
    'cards': _cards.map(_cardToJson).toList(),
    'groups': _groups.map(_groupToJson).toList(),
  };

  /// Sanitized seed per card id. A card's seed never changes, and
  /// [SensitiveDataPolicy.persistedValue] is a pure function of
  /// (value, utilityId), so the scan runs once per card, not per snapshot.
  final Map<int, ({String seed, String? utilityId, String? persisted})>
  _persistedSeeds =
      <int, ({String seed, String? utilityId, String? persisted})>{};

  String? _persistedSeed(CanvasCard c) {
    final String? seed = c.seed;
    if (seed == null) return null;
    final String? utilityId = c.toolDescriptor?.id;
    final ({String seed, String? utilityId, String? persisted})? cached =
        _persistedSeeds[c.id];
    if (cached != null &&
        identical(cached.seed, seed) &&
        cached.utilityId == utilityId) {
      return cached.persisted;
    }
    final String? persisted = SensitiveDataPolicy.persistedValue(
      seed,
      utilityId: utilityId,
    );
    _persistedSeeds[c.id] = (
      seed: seed,
      utilityId: utilityId,
      persisted: persisted,
    );
    return persisted;
  }

  Map<String, dynamic> _cardToJson(CanvasCard c) {
    final String? seed = _persistedSeed(c);
    return <String, dynamic>{
      'id': c.id,
      ...switch (c.content) {
        ToolWindow tw => <String, dynamic>{'tool': tw.descriptor.id},
        SystemWindow sw => <String, dynamic>{'system': sw.app.name},
      },
      'x': c.x,
      'y': c.y,
      'w': c.width,
      'z': c.z,
      'seed': ?seed,
      if (c.minimized) 'minimized': true,
      if (c.maximized) 'maximized': true,
      if (c.height != null) 'h': c.height,
      if (c.restoreBounds != null)
        'rb': <String, dynamic>{
          'x': c.restoreBounds!.x,
          'y': c.restoreBounds!.y,
          'w': c.restoreBounds!.width,
          if (c.restoreBounds!.height != null) 'h': c.restoreBounds!.height,
        },
    };
  }

  /// Sanitized canonical per group id, keyed like [_persistedSeeds]: the
  /// canonical only changes on an emit, so a snapshot (focus, drag commit)
  /// reuses the last scan instead of re-running it over a large value.
  final Map<int, ({String canonical, bool sensitive, String persisted})>
  _persistedCanonicals =
      <int, ({String canonical, bool sensitive, String persisted})>{};

  String _persistedCanonical(LinkGroup group, bool sensitive) {
    final String canonical = group.canonical.value;
    final ({String canonical, bool sensitive, String persisted})? cached =
        _persistedCanonicals[group.id];
    if (cached != null &&
        identical(cached.canonical, canonical) &&
        cached.sensitive == sensitive) {
      return cached.persisted;
    }
    final String persisted =
        SensitiveDataPolicy.persistedValue(canonical, sensitive: sensitive) ??
        '';
    _persistedCanonicals[group.id] = (
      canonical: canonical,
      sensitive: sensitive,
      persisted: persisted,
    );
    return persisted;
  }

  Map<String, dynamic> _groupToJson(LinkGroup group) {
    final bool hasSensitiveMember = _membersContainSensitiveTool(group.members);
    return <String, dynamic>{
      'id': group.id,
      'type': group.type.name,
      'canonical': _persistedCanonical(group, hasSensitiveMember),
      'members': group.members.toList(),
    };
  }

  bool _membersContainSensitiveTool(Iterable<int> members) => members.any(
    (int id) => _cards.any(
      (CanvasCard card) =>
          card.id == id &&
          SensitiveDataPolicy.isSensitiveTool(card.toolDescriptor?.id),
    ),
  );

  /// Replaces the canvas from a [toJson] map. Cards whose tool id no longer
  /// exists in the catalog are dropped. Unknown system app names are dropped.
  /// Notifies but does not re-persist.
  void applyJson(Map<String, dynamic> json) {
    _cards.clear();
    _groups.clear();
    _persistedSeeds.clear();
    _persistedCanonicals.clear();
    int maxId = 0;
    int maxZ = 0;
    for (final dynamic raw
        in (json['cards'] as List<dynamic>? ?? const <dynamic>[])) {
      final Map<String, dynamic> m = raw as Map<String, dynamic>;
      final WindowContent? content;
      if (m.containsKey('system')) {
        final String name = m['system'] as String;
        final SystemApp? app = SystemApp.values.cast<SystemApp?>().firstWhere(
          (SystemApp? a) => a!.name == name,
          orElse: () => null,
        );
        if (app == null) continue;
        content = SystemWindow(app);
      } else {
        final UtilityDescriptor? d = UtilityCatalog.byIdOrNull(
          m['tool'] as String,
        );
        if (d == null) continue;
        content = ToolWindow(d);
      }
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
          content: content,
          x: (m['x'] as num).toDouble(),
          y: (m['y'] as num).toDouble(),
          width: (m['w'] as num).toDouble(),
          seed: SensitiveDataPolicy.persistedValue(
            m['seed'] as String?,
            utilityId: content is ToolWindow ? content.descriptor.id : null,
          ),
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
          canonical:
              SensitiveDataPolicy.persistedValue(
                m['canonical'] as String?,
                sensitive: _membersContainSensitiveTool(members),
              ) ??
              '',
        )..members.addAll(members),
      );
    }
    _nextGroupId = (json['nextGroupId'] as num?)?.toInt() ?? (maxGid + 1);
    if (_nextGroupId <= maxGid) _nextGroupId = maxGid + 1;

    _syncWatchers();
    notifyListeners();
  }

  static ContentType? _contentTypeOrNull(String? name) {
    for (final ContentType t in ContentType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Restores the auto-saved canvas from prefs. No-op without a backend or
  /// when the stored snapshot is missing or corrupt. Re-writes the snapshot
  /// only when restoring changed it (a dropped tool, a scrubbed seed) — a
  /// clean restore costs no write.
  void restore() {
    final String? raw = _prefs?.getString(currentKey);
    if (raw == null) return;
    try {
      applyJson(jsonDecode(raw) as Map<String, dynamic>);
      _persist(unlessEqualTo: raw);
    } catch (_) {
      // Corrupt snapshot — start clean rather than crash.
      final SharedPreferences? prefs = _prefs;
      if (prefs != null) unawaited(prefs.remove(currentKey));
    }
  }

  /// Trailing debounce for high-frequency snapshots (link emits, focus).
  static const Duration persistDebounce = Duration(milliseconds: 500);

  /// Bumped by [clearPersistedSensitiveSession] so a snapshot scheduled
  /// before the clear can't re-write the cleared session on its flush.
  static int _clearEpoch = 0;

  Timer? _persistTimer;
  int _pendingEpoch = 0;

  /// Number of snapshot writes to prefs (for tests).
  @visibleForTesting
  int debugPersistWrites = 0;

  /// Whether a debounced snapshot is waiting to be written.
  bool get hasPendingPersist => _persistTimer != null;

  void _schedulePersist() {
    if (_prefs == null) return;
    _pendingEpoch = _clearEpoch;
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDebounce, flushPersist);
  }

  /// Writes a pending debounced snapshot now. The desktop shell calls this
  /// when the app is paused / hidden; [dispose] calls it too.
  void flushPersist() {
    if (_persistTimer == null) return;
    _persistTimer!.cancel();
    _persistTimer = null;
    if (_pendingEpoch != _clearEpoch) return; // superseded by a clear
    _persist();
  }

  /// Writes the snapshot now. With [unlessEqualTo], skips the write when the
  /// encoded snapshot matches that already-stored string.
  void _persist({String? unlessEqualTo}) {
    // An immediate write covers anything a pending debounce would write.
    _persistTimer?.cancel();
    _persistTimer = null;
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final String encoded = jsonEncode(toJson());
    if (encoded == unlessEqualTo) return;
    debugPersistWrites++;
    unawaited(prefs.setString(currentKey, encoded));
  }

  /// Clears the auto-restored session and scrubs legacy saved layouts.
  static Future<void> clearPersistedSensitiveSession() async {
    _clearEpoch++;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(currentKey);
    await _sanitizePersistedLayouts(prefs);
  }

  /// Number of saved-layout rewrites by the startup / clear sanitizer (for
  /// tests).
  @visibleForTesting
  static int debugLayoutSanitizeWrites = 0;

  /// Re-sanitizes every saved layout, writing only when that changed the
  /// stored string — so a clean launch costs a decode + encode, not a write.
  static Future<void> _sanitizePersistedLayouts(SharedPreferences prefs) async {
    final String? raw = prefs.getString(layoutsKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> stored =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, dynamic> safe = <String, dynamic>{};
      for (final MapEntry<String, dynamic> entry in stored.entries) {
        if (SensitiveDataPolicy.containsSensitiveArtifact(entry.key) ||
            entry.value is! Map<String, dynamic>) {
          continue;
        }
        final CanvasController controller = CanvasController()
          ..applyJson(entry.value as Map<String, dynamic>);
        safe[entry.key] = controller.toJson();
      }
      final String encoded = jsonEncode(safe);
      if (encoded == raw) return;
      debugLayoutSanitizeWrites++;
      await prefs.setString(layoutsKey, encoded);
    } catch (_) {
      await prefs.remove(layoutsKey);
    }
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
  List<String> get layoutNames =>
      _layouts().keys
          .where(
            (String name) =>
                !SensitiveDataPolicy.containsSensitiveArtifact(name),
          )
          .toList()
        ..sort();

  /// Saves the current canvas under [name] (overwriting any same-named layout).
  void saveLayout(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty ||
        SensitiveDataPolicy.containsSensitiveArtifact(trimmed) ||
        _prefs == null) {
      return;
    }
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
    if (g.members.length < 2) {
      _groups.remove(g);
      _persistedCanonicals.remove(g.id);
    }
    return true;
  }

  void _emit(LinkGroup g, String value) {
    if (!_groups.contains(g)) return;
    if (g.canonical.value == value) return; // idempotent → cycles terminate
    g.canonical.value = value;
    // Linked bodies emit on every debounced parse: coalesce the snapshot.
    _schedulePersist();
  }
}

/// A bare notifier the controller fires for geometry-only ticks.
class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
