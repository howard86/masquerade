import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility_catalog.dart';
import '../utils/sensitive_data_policy.dart';
import 'link_group.dart';
import 'window_content.dart';
import 'z_order_store.dart';

/// Saved geometry before a maximize/snap so the window can restore.
typedef RestoreBounds = ({double x, double y, double width, double? height});

/// Why two canvas cards cannot share a live-link group.
enum LinkIssue {
  sourceMissing,
  targetMissing,
  sameWindow,
  alreadyLinked,
  notToolWindow,
  sourceUnsupported,
  targetUnsupported,
  groupTypeConflict,
  shapeMismatch,
  noSender,
}

extension LinkIssueMessage on LinkIssue {
  String message(ContentType type) => switch (this) {
    LinkIssue.sourceMissing => 'The source window is no longer open.',
    LinkIssue.targetMissing => 'The target window is no longer open.',
    LinkIssue.sameWindow => 'Choose a different window.',
    LinkIssue.alreadyLinked => 'These windows are already linked.',
    LinkIssue.notToolWindow => 'Live links work between tool windows.',
    LinkIssue.sourceUnsupported =>
      'Drop on the desktop to open it in a new window.',
    LinkIssue.targetUnsupported =>
      'This target cannot receive a live ${type.name} value.',
    LinkIssue.groupTypeConflict =>
      'A linked window already uses a different value type. Unlink it first.',
    LinkIssue.shapeMismatch => 'These windows read different kinds of text.',
    LinkIssue.noSender => 'One of these windows must be able to send.',
  };
}

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
  final ZOrderStore _z = ZOrderStore();
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
  List<CanvasCard> get cardsByZ {
    final Map<int, CanvasCard> byId = <int, CanvasCard>{
      for (final CanvasCard c in _cards) c.id: c,
    };
    return <CanvasCard>[for (final int id in _z.order) byId[id]!];
  }

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
    );
    _cards.add(card);
    _z.add(card.id);
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
    );
    _cards.add(card);
    _z.add(card.id);
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
    _z.remove(id);
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
    _z.clear();
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
    final bool raised = _z.raise(id);
    if (_focusedId == id && !raised) return;
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
    _replace(i, _cards[i].copyWith(minimized: false));
    _z.raise(id);
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
      ),
    );
    _z.raise(id);
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
      ),
    );
    _z.raise(id);
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
    'nextZ': _z.length + 1,
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
      'z': _z.rankOf(c.id) + 1,
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
      if (group.roles.isNotEmpty)
        'roles': <String, String>{
          for (final MapEntry<int, LinkRole> e in group.roles.entries)
            '${e.key}': e.value.name,
        },
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
    // Drops duplicate, stale, or incompatible saved membership before any tool
    // body can subscribe to the groups.
    final Set<int> claimedLinkMembers = <int>{};
    _persistedSeeds.clear();
    _persistedCanonicals.clear();
    int maxId = 0;
    final Map<int, int> savedZ = <int, int>{};
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
      savedZ[id] = z;
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
          minimized: m['minimized'] as bool? ?? false,
          maximized: m['maximized'] as bool? ?? false,
          height: (m['h'] as num?)?.toDouble(),
          restoreBounds: rb,
        ),
      );
    }
    _nextId = (json['nextId'] as num?)?.toInt() ?? (maxId + 1);
    if (_nextId <= maxId) _nextId = maxId + 1;
    _z.restore(
      (_cards.map((CanvasCard c) => c.id).toList()..sort((int a, int b) {
        final int byZ = savedZ[a]!.compareTo(savedZ[b]!);
        return byZ != 0 ? byZ : a.compareTo(b);
      })),
    );
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
      // Preserve privacy provenance from the original group even when an
      // unsupported sensitive member is removed by compatibility sanitation.
      final bool hadSensitiveMember = _membersContainSensitiveTool(members);
      final int gid = (m['id'] as num).toInt();
      maxGid = gid > maxGid ? gid : maxGid;
      final Set<int> validMembers = members.where((int cid) {
        if (claimedLinkMembers.contains(cid)) return false;
        final CanvasCard card = _cards.firstWhere(
          (CanvasCard c) => c.id == cid,
        );
        return _supportsLiveLink(card, type);
      }).toSet();
      if (type == ContentType.text) _dropShapeConflicts(validMembers);
      if (validMembers.length < 2 ||
          _groups.any((LinkGroup g) => g.id == gid)) {
        continue;
      }
      claimedLinkMembers.addAll(validMembers);
      _groups.add(
        LinkGroup(
          id: gid,
          type: type,
          canonical:
              SensitiveDataPolicy.persistedValue(
                m['canonical'] as String?,
                sensitive: hadSensitiveMember,
              ) ??
              '',
        )..members.addAll(validMembers),
      );
      final Object? rawRoles = m['roles'];
      if (rawRoles is Map) {
        for (final MapEntry<dynamic, dynamic> e in rawRoles.entries) {
          final int? cid = int.tryParse('${e.key}');
          if (cid == null || !validMembers.contains(cid)) continue;
          if (e.value == LinkRole.receive.name) {
            _groups.last.roles[cid] = LinkRole.receive;
          }
        }
      }
      for (final int cid in validMembers) {
        final LinkCapability? cap = _capability(cid);
        if (cap == LinkCapability.followOnly) {
          _groups.last.roles[cid] = LinkRole.receive;
        } else if (cap == LinkCapability.sourceOnly) {
          _groups.last.roles.remove(cid);
        }
      }
      _ensureSender(_groups.last);
      if (!_hasSender(_groups.last)) {
        for (final int cid in _groups.last.members) {
          claimedLinkMembers.remove(cid);
        }
        _persistedCanonicals.remove(_groups.last.id);
        _groups.removeLast();
      }
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

  bool _supportsLiveLink(CanvasCard card, ContentType type) {
    final UtilityDescriptor? descriptor = card.toolDescriptor;
    return descriptor != null &&
        descriptor.supportsLiveLink &&
        descriptor.liveLinkTypes.contains(type);
  }

  LinkCapability? _capability(int cardId) =>
      _cardById(cardId)?.toolDescriptor?.linkCapability;

  /// Whether [g] has a member able to send (non-follower, not follow-only).
  bool _hasSender(LinkGroup g) => g.members.any(
    (int id) =>
        g.roleOf(id).sends && _capability(id) != LinkCapability.followOnly,
  );

  /// Whether a sender with [s] can feed text to [r].
  static bool _shapeOk(UtilityDescriptor s, UtilityDescriptor r) =>
      r.linkAcceptsTextShapes.contains(s.linkTextShape);

  /// Restore sanitation: removes members from [ids] until every
  /// sender -> receiver text pair is compatible (sender = not follow-only;
  /// receiver = not source-only).
  void _dropShapeConflicts(Set<int> ids) {
    bool conflict(int s, int r) {
      final UtilityDescriptor? sd = _cardById(s)?.toolDescriptor;
      final UtilityDescriptor? rd = _cardById(r)?.toolDescriptor;
      return s != r &&
          sd != null &&
          rd != null &&
          sd.linkCapability != LinkCapability.followOnly &&
          rd.linkCapability != LinkCapability.sourceOnly &&
          !_shapeOk(sd, rd);
    }

    while (true) {
      int? worst;
      int worstCount = 0;
      for (final int id in ids) {
        int n = 0;
        for (final int o in ids) {
          if (conflict(id, o) || conflict(o, id)) n++;
        }
        if (n > worstCount) {
          worstCount = n;
          worst = id;
        }
      }
      if (worst == null) return;
      ids.remove(worst);
    }
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

  /// Whether [group] holds a sensitive tool, so its canonical value must only
  /// be shown through [SensitiveDataPolicy.safePreview] with `sensitive: true`.
  bool groupIsSensitive(LinkGroup group) =>
      _membersContainSensitiveTool(group.members);

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
      seedOnAttach: g.seedOwnerCardId == cardId,
      isSeedOwner: () =>
          _groups.contains(g) &&
          g.members.contains(cardId) &&
          g.seedOwnerCardId == cardId,
      onSeedConsumed: () => _consumeSeedOwner(g, cardId),
      role: () => g.roleOf(cardId),
      onEmit: (String value) => _emit(g, value),
    );
  }

  /// Whether [cardId] is linked as follow-only.
  bool isFollower(int cardId) =>
      groupForCard(cardId)?.roleOf(cardId) == LinkRole.receive;

  /// Whether [cardId] may become a follower: linked, and at least one other
  /// member is not a follower (a group always keeps a sender).
  bool canFollow(int cardId) {
    final LinkGroup? g = groupForCard(cardId);
    if (g == null || _capability(cardId) == LinkCapability.sourceOnly) {
      return false;
    }
    return g.members.any(
      (int id) =>
          id != cardId &&
          g.roleOf(id).sends &&
          _capability(id) != LinkCapability.followOnly,
    );
  }

  /// Whether [cardId]'s follow state is fixed by its tool (follow-only tools
  /// always follow; source-only tools never do).
  bool followFixed(int cardId) {
    final LinkCapability? c = _capability(cardId);
    return c == LinkCapability.followOnly || c == LinkCapability.sourceOnly;
  }

  /// Sets [cardId] follow-only or two-way. Returns false (no change) when
  /// unlinked or when it would leave the group without a sender.
  bool setFollower(int cardId, bool follows) {
    final LinkGroup? g = groupForCard(cardId);
    if (g == null || followFixed(cardId)) return false;
    if (follows && !canFollow(cardId)) return false;
    final LinkRole role = follows ? LinkRole.receive : LinkRole.both;
    if (g.roleOf(cardId) == role) return true;
    _storeRole(g, cardId, role);
    notifyListeners();
    _persist();
    return true;
  }

  /// The link type a source → target link should use: the downstream
  /// (target) window's default input type. With a group on either side, that
  /// group's type if both tools support it and the groups agree.
  ContentType? defaultLinkType(
    UtilityDescriptor source,
    UtilityDescriptor target, {
    LinkGroup? sourceGroup,
    LinkGroup? targetGroup,
  }) {
    if (!source.supportsLiveLink || !target.supportsLiveLink) {
      return null;
    }
    if (sourceGroup != null || targetGroup != null) {
      final ContentType? t = sourceGroup?.type ?? targetGroup?.type;
      if (t == null) return null;
      if (sourceGroup != null && sourceGroup.type != t) return null;
      if (targetGroup != null && targetGroup.type != t) return null;
      return source.liveLinkTypes.contains(t) &&
              target.liveLinkTypes.contains(t)
          ? t
          : null;
    }
    for (final ContentType t in target.liveLinkTypes) {
      if (source.liveLinkTypes.contains(t)) return t;
    }
    return null;
  }

  void _storeRole(LinkGroup g, int cardId, LinkRole role) {
    if (role == LinkRole.both) {
      g.roles.remove(cardId);
    } else {
      g.roles[cardId] = role;
    }
  }

  /// Enforces the invariant that a group has at least one non-follower: when
  /// every member follows, [preferred] (or every member) becomes two-way.
  void _ensureSender(LinkGroup g, {int? preferred}) {
    if (g.members.isEmpty || _hasSender(g)) return;
    bool canSend(int id) => _capability(id) != LinkCapability.followOnly;
    if (preferred != null &&
        g.members.contains(preferred) &&
        canSend(preferred)) {
      g.roles.remove(preferred);
    } else {
      for (final int id in g.members.where(canSend)) {
        g.roles.remove(id);
      }
    }
  }

  void _consumeSeedOwner(LinkGroup group, int cardId) {
    if (_groups.contains(group) &&
        group.members.contains(cardId) &&
        group.seedOwnerCardId == cardId) {
      group.seedOwnerCardId = null;
    }
  }

  /// Returns the reason the proposed link is invalid, or null when it can be
  /// made. [a] is the source and [b] the target.
  LinkIssue? linkIssueFor(int a, int b, {required ContentType type}) {
    if (a == b) return LinkIssue.sameWindow;
    final CanvasCard? source = _cardById(a);
    if (source == null) return LinkIssue.sourceMissing;
    final CanvasCard? target = _cardById(b);
    if (target == null) return LinkIssue.targetMissing;
    if (source.toolDescriptor == null || target.toolDescriptor == null) {
      return LinkIssue.notToolWindow;
    }
    if (!_supportsLiveLink(source, type)) return LinkIssue.sourceUnsupported;
    if (!_supportsLiveLink(target, type)) return LinkIssue.targetUnsupported;
    final LinkGroup? sourceGroup = groupForCard(a);
    final LinkGroup? targetGroup = groupForCard(b);
    if ((sourceGroup != null && sourceGroup.type != type) ||
        (targetGroup != null && targetGroup.type != type)) {
      return LinkIssue.groupTypeConflict;
    }
    if (sourceGroup != null && identical(sourceGroup, targetGroup)) {
      return LinkIssue.alreadyLinked;
    }
    bool follows(int id) => _capability(id) == LinkCapability.followOnly;
    if (follows(a) && follows(b) && !_otherSender(sourceGroup, targetGroup)) {
      return LinkIssue.noSender;
    }
    if (type == ContentType.text) {
      final Set<int> ids = <int>{
        ...?sourceGroup?.members,
        ...?targetGroup?.members,
        a,
        b,
      };
      bool sends(int id) =>
          !follows(id) && (groupForCard(id)?.roleOf(id) ?? LinkRole.both).sends;
      for (final int s in ids.where(sends)) {
        final UtilityDescriptor sd = _cardById(s)!.toolDescriptor!;
        for (final int r in ids) {
          if (r == s) continue;
          final UtilityDescriptor rd = _cardById(r)!.toolDescriptor!;
          if (rd.linkCapability == LinkCapability.sourceOnly) continue;
          if (!_shapeOk(sd, rd)) return LinkIssue.shapeMismatch;
        }
      }
    }
    return null;
  }

  /// Whether the group(s) already hold a member that can send.
  bool _otherSender(LinkGroup? x, LinkGroup? y) =>
      (x != null && _hasSender(x)) || (y != null && _hasSender(y));

  CanvasCard? _cardById(int id) {
    for (final CanvasCard card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// Links [a] and [b] into a shared group of [type]. A new group uses
  /// [seedCanonical] when supplied, otherwise the source card seeds it when
  /// its body attaches. Existing groups retain their canonical value; joining
  /// two groups merges them using the source group's canonical value. Invalid
  /// or stale operations are rejected without changing state. Returns the
  /// group id, or null if the link could not be made. A card lives in at most
  /// one group.
  int? linkCards(
    int a,
    int b, {
    required ContentType type,
    String? seedCanonical,
    bool targetFollows = false,
  }) {
    final LinkGroup? sourceGroup = groupForCard(a);
    final LinkGroup? targetGroup = groupForCard(b);
    if (_cardById(a) != null &&
        _cardById(b) != null &&
        sourceGroup != null &&
        identical(sourceGroup, targetGroup) &&
        sourceGroup.type == type &&
        sourceGroup.members.contains(a) &&
        sourceGroup.members.contains(b)) {
      // Re-linking an existing pair applies the requested follow state.
      final LinkRole before = sourceGroup.roleOf(b);
      if (targetFollows &&
          before.sends &&
          _capability(b) != LinkCapability.sourceOnly) {
        _storeRole(sourceGroup, b, LinkRole.receive);
        _ensureSender(sourceGroup, preferred: a);
        notifyListeners();
        _persist();
      }
      return sourceGroup.id;
    }
    if (linkIssueFor(a, b, type: type) != null) return null;

    final LinkGroup group;
    if (sourceGroup != null) {
      group = sourceGroup;
    } else if (targetGroup != null) {
      group = targetGroup;
    } else {
      group = LinkGroup(
        id: _nextGroupId++,
        type: type,
        canonical: seedCanonical ?? '',
        seedOwnerCardId: seedCanonical != null
            ? null
            : (_capability(a) == LinkCapability.followOnly ? b : a),
      );
      _groups.add(group);
    }

    if (sourceGroup != null &&
        targetGroup != null &&
        !identical(sourceGroup, targetGroup)) {
      // The source group's canonical wins, matching the direction of the
      // explicit source → target action. Membership is moved atomically so no
      // card is visible in two groups during or after the merge.
      group.members.addAll(targetGroup.members);
      group.roles.addAll(targetGroup.roles);
      _groups.remove(targetGroup);
      _persistedCanonicals.remove(targetGroup.id);
    }

    group.members
      ..add(a)
      ..add(b);
    // Follow-only tools always follow; a source-only target never does
    // (targetFollows is ignored for it).
    if (_capability(a) == LinkCapability.followOnly) {
      _storeRole(group, a, LinkRole.receive);
    }
    if (_capability(b) == LinkCapability.followOnly ||
        (targetFollows && _capability(b) != LinkCapability.sourceOnly)) {
      _storeRole(group, b, LinkRole.receive);
    }
    _ensureSender(
      group,
      preferred: _capability(a) == LinkCapability.followOnly ? b : a,
    );
    notifyListeners();
    _persist();
    return group.id;
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
    g.roles.remove(cardId);
    if (g.seedOwnerCardId == cardId) g.seedOwnerCardId = null;
    if (g.members.length >= 2) _ensureSender(g);
    if (g.members.length < 2 || !_hasSender(g)) {
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
