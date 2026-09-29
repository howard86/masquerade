import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../state/canvas_controller.dart';
import '../../state/detection_preference_controller.dart';
import '../../state/link_group.dart';
import '../../state/window_content.dart';
import '../../theme/mq_colors.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../widgets/desktop/command_palette.dart';
import '../../widgets/desktop/desktop_icon_grid.dart';
import '../../widgets/desktop/pipe.dart';
import '../../widgets/desktop/tool_card_frame.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
import '../../widgets/desktop/desktop_context_menu.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/desktop/shortcuts_hud.dart';

/// Header-toggle link pairings (see docs/adr/0001): a card's link button opens
/// this fixed partner tool and links the two on one canonical type. Keyed by
/// tool id → its partner tool + the shared canonical type. Only *unambiguous*
/// pairs live here; tools reachable on several types (or with no clean tool
/// partner) link via phase-4 drop-to-link instead. The canvas owns this; the
/// bodies stay shell-agnostic.
///
/// Math sits in two pairs (number ↔ math, epoch ↔ math); its toggle defaults
/// to Number Base, and the Timestamp pairing is reachable via drop-to-link.
const Map<String, ({String partnerId, ContentType type})> _linkPartners =
    <String, ({String partnerId, ContentType type})>{
      'base64': (partnerId: 'json', type: ContentType.text),
      'json': (partnerId: 'base64', type: ContentType.text),
      'number_base': (partnerId: 'math', type: ContentType.number),
      'math': (partnerId: 'number_base', type: ContentType.number),
      'list': (partnerId: 'diff', type: ContentType.text),
      'diff': (partnerId: 'list', type: ContentType.text),
    };

typedef _ToolBodyCacheEntry = ({
  UtilityDescriptor descriptor,
  String? seed,
  ValueListenable<String>? inbound,
  Widget body,
});

/// The desktop work surface: a pannable canvas hosting the fixed
/// [DesktopIconGrid] (single-click an icon to open a tool) with draggable tool
/// cards floating above it. Menubar items cover ⌘K / paste / close-all, so the
/// canvas carries no chrome of its own.
///
/// Owns no state itself beyond the pan offset — the open cards live in the
/// injected [CanvasController] so the shell can keep them across nav switches
/// (and, later, persist them).
class DesktopCanvas extends StatefulWidget {
  const DesktopCanvas({super.key, required this.controller});

  final CanvasController controller;

  @override
  State<DesktopCanvas> createState() => _DesktopCanvasState();
}

class _DesktopCanvasState extends State<DesktopCanvas> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'canvas');
  final Map<int, _ToolBodyCacheEntry> _toolBodies =
      <int, _ToolBodyCacheEntry>{};

  /// Anchors the canvas surface so a pipe drop's global offset can be mapped to
  /// canvas-local coordinates (drop − surfaceTopLeft − pan).
  final GlobalKey _surfaceKey = GlobalKey();

  /// Pan offset. A notifier (not state) so panning repaints the dot grid and
  /// repositions cards without rebuilding the desktop.
  final ValueNotifier<Offset> _pan = ValueNotifier<Offset>(Offset.zero);

  CanvasController get _c => widget.controller;

  static const List<LogicalKeyboardKey> _digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// The card whose title bar is being dragged (drives the snap preview).
  final ValueNotifier<int?> _draggingCardId = ValueNotifier<int?>(null);
  final Set<int> _animatingMinimizedIds = <int>{};
  final Map<int, bool> _prevMinimized = <int, bool>{};

  /// Built once: the launcher grid depends on no canvas state, so reusing the
  /// instance keeps its ~30 tiles out of every canvas rebuild.
  late final Widget _iconGrid = DesktopIconGrid(
    onOpen: (UtilityDescriptor u) => _c.openTool(u),
    onOpenSystem: (SystemApp app) => _c.openSystem(app),
  );

  /// Snap preview + link lines follow every geometry tick, pan and drag.
  late Listenable _overlayListenable = _overlayFor(_c);

  Listenable _overlayFor(CanvasController c) =>
      Listenable.merge(<Listenable?>[c.geometry, _pan, _draggingCardId]);

  /// Per-card frame cache keyed by card id. The cached instance is returned
  /// while its key (every non-geometry input) is unchanged, so a move tick
  /// doesn't rebuild the frame; its body comes from [_toolBodies].
  final Map<int, ({Object key, Widget frame})> _frames =
      <int, ({Object key, Widget frame})>{};
  final Map<int, ({Object watcher, Listenable listenable})> _cardListenables =
      <int, ({Object watcher, Listenable listenable})>{};

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    for (final card in _c.cards) {
      _prevMinimized[card.id] = card.minimized;
    }
  }

  @override
  void didUpdateWidget(DesktopCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChange);
    _toolBodies.clear();
    _frames.clear();
    _cardListenables.clear();
    _overlayListenable = _overlayFor(_c);
    _prevMinimized.clear();
    for (final CanvasCard card in _c.cards) {
      _prevMinimized[card.id] = card.minimized;
    }
    _c.addListener(_onChange);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _focusNode.dispose();
    _pan.dispose();
    _draggingCardId.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final List<CanvasCard> currentCards = _c.cards;
    setState(() {
      for (final card in currentCards) {
        final bool wasMinimized = _prevMinimized[card.id] ?? false;
        if (card.minimized && !wasMinimized) {
          _animatingMinimizedIds.add(card.id);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              setState(() {
                _animatingMinimizedIds.remove(card.id);
              });
            }
          });
        } else if (!card.minimized && wasMinimized) {
          _animatingMinimizedIds.add(card.id);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              setState(() {
                _animatingMinimizedIds.remove(card.id);
              });
            }
          });
        }
        _prevMinimized[card.id] = card.minimized;
      }
      final Set<int> open = <int>{
        for (final CanvasCard card in currentCards) card.id,
      };
      _frames.removeWhere((int id, _) => !open.contains(id));
      _toolBodies.removeWhere((int id, _) => !open.contains(id));
      _cardListenables.removeWhere((int id, _) => !open.contains(id));
    });
  }

  Future<void> _openViaPalette() async {
    final PaletteResult? r = await showCommandPalette(context);
    if (r != null && mounted) _c.openTool(r.tool, seed: r.seed);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;
    final HardwareKeyboard hw = HardwareKeyboard.instance;

    if (k == LogicalKeyboardKey.escape && _c.focusedId != null) {
      _c.close(_c.focusedId!);
      return KeyEventResult.handled;
    }
    if ((hw.isMetaPressed || hw.isControlPressed) &&
        k == LogicalKeyboardKey.keyK) {
      _openViaPalette();
      return KeyEventResult.handled;
    }
    if (hw.isAltPressed &&
        k == LogicalKeyboardKey.keyD &&
        _c.focusedId != null) {
      _c.duplicate(_c.focusedId!);
      return KeyEventResult.handled;
    }
    if (hw.isAltPressed && k == LogicalKeyboardKey.slash) {
      showShortcutsHUD(context);
      return KeyEventResult.handled;
    }
    if (hw.isAltPressed) {
      final int slot = _digits.indexOf(k);
      if (slot >= 0) {
        _c.focusSlot(slot + 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: _surface(context),
    );
  }

  Widget _surface(BuildContext context) {
    final c = context.mq.colors;
    final List<CanvasCard> zCards = _c.cardsByZ;
    final List<CanvasCard> openOrder = _c.cards;
    final Size? canvasSize = _canvasSize;

    return ClipRect(
      child: ColoredBox(
        key: _surfaceKey,
        color: const Color(0x00000000),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DragTarget<PipePayload>(
                onAcceptWithDetails: _onDropOnCanvas,
                builder:
                    (
                      BuildContext context,
                      List<PipePayload?> candidate,
                      List<dynamic> rejected,
                    ) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (DragUpdateDetails d) =>
                          _pan.value += d.delta,
                      onSecondaryTapDown: (TapDownDetails details) =>
                          _showWallpaperContextMenu(
                            context,
                            details.globalPosition,
                          ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _DotGridPainter(
                            color: c.border,
                            offset: _pan,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            Positioned.fill(child: _iconGrid),
            if (_c.hasLinks)
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _overlayListenable,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      painter: _LinkLinePainter(
                        segments: _linkSegments(_c.cards, _pan.value),
                        color: c.warning,
                      ),
                    ),
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: _overlayListenable,
              builder: (BuildContext context, Widget? _) => _snapPreview(c),
            ),
            for (final CanvasCard card in zCards)
              if (!card.minimized || _animatingMinimizedIds.contains(card.id))
                _buildCardWrapper(
                  card: card,
                  openOrder: openOrder,
                  canvasSize: canvasSize ?? const Size(1200, 800),
                ),
          ],
        ),
      ),
    );
  }

  /// The half/full-tile outline shown while a card is dragged near an edge.
  Widget _snapPreview(MqColors c) {
    final int? draggingId = _draggingCardId.value;
    final CanvasCard? draggingCard = draggingId == null
        ? null
        : _cardById(draggingId);
    Rect? previewRect;
    // The surface may not be laid out yet on the first build; only a drag
    // (which implies a laid-out surface) needs its size.
    final Size? canvasSize = draggingCard == null ? null : _canvasSize;
    if (canvasSize != null && draggingCard != null) {
      if (draggingCard.x <= _snapThreshold) {
        previewRect = Rect.fromLTWH(
          0,
          0,
          canvasSize.width / 2,
          canvasSize.height,
        );
      } else if (draggingCard.x + draggingCard.width >=
          canvasSize.width - _snapThreshold) {
        previewRect = Rect.fromLTWH(
          canvasSize.width / 2,
          0,
          canvasSize.width / 2,
          canvasSize.height,
        );
      } else if (draggingCard.y <= _snapThreshold) {
        previewRect = Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
      }
    }
    if (previewRect == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final Offset pan = _pan.value;
    return Positioned(
      left: previewRect.left + pan.dx,
      top: previewRect.top + pan.dy,
      width: previewRect.width,
      height: previewRect.height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(MqSpacing.sm),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(MqRadius.md),
          border: Border.all(
            color: c.accent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.accent.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  CanvasCard? _cardById(int id) {
    for (final CanvasCard card in _c.cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  void _onDropOnCanvas(DragTargetDetails<PipePayload> details) {
    final List<DetectionMatch<Object?>> matches =
        DetectionPreferenceScope.of(context).rank(
          UtilityCatalog.detectArtifacts(
            details.data.value,
            provenance: ArtifactProvenance.liveLink,
          ),
        );
    if (matches.isEmpty) return;
    final RenderBox? box =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(details.offset);
    final int id = _c.openTool(
      UtilityCatalog.byId(matches.first.primaryToolId),
      seed: matches.first.artifact.rawValue,
    );
    _c.moveTo(id, local.dx - _pan.value.dx, local.dy - _pan.value.dy);
    _c.commit();
  }

  Widget _buildCardWrapper({
    required CanvasCard card,
    required List<CanvasCard> openOrder,
    required Size canvasSize,
  }) {
    final int slot = openOrder.indexWhere((c) => c.id == card.id) + 1;
    final int id = card.id;

    if (_animatingMinimizedIds.contains(id)) {
      final Widget frame = _cardFrame(card, slot: slot);
      return ValueListenableBuilder<Offset>(
        valueListenable: _pan,
        builder: (BuildContext context, Offset pan, Widget? _) =>
            _AnimatedWindow(
              card: card,
              slot: slot,
              pan: pan,
              canvasSize: canvasSize,
              child: frame,
            ),
      );
    }

    // Only this card's geometry and the pan re-run this builder; the frame
    // (and the tool body inside it) comes back from the cache unless a
    // non-geometry input changed.
    return ListenableBuilder(
      key: ValueKey<int>(id),
      listenable: _cardListenable(id),
      builder: (BuildContext context, Widget? _) {
        final CanvasCard live = _c.watchCard(id).value;
        final Offset pan = _pan.value;
        return Positioned(
          left: live.x + pan.dx,
          top: live.y + pan.dy,
          child: SizedBox(
            width: live.width,
            height: live.height,
            child: _cardFrame(live, slot: slot),
          ),
        );
      },
    );
  }

  Listenable _cardListenable(int id) {
    final ValueListenable<CanvasCard> watcher = _c.watchCard(id);
    final ({Object watcher, Listenable listenable})? cached =
        _cardListenables[id];
    if (cached != null && identical(cached.watcher, watcher)) {
      return cached.listenable;
    }
    final Listenable merged = Listenable.merge(<Listenable?>[watcher, _pan]);
    _cardListenables[id] = (watcher: watcher, listenable: merged);
    return merged;
  }

  /// The cached frame for [card], rebuilt only when an input other than its
  /// position / width changes.
  Widget _cardFrame(CanvasCard card, {required int slot}) {
    final LinkGroup? group = _c.groupForCard(card.id);
    final Object key = (
      card.content,
      slot,
      _c.focusedId == card.id,
      card.maximized,
      card.height,
      card.seed,
      group,
    );
    final ({Object key, Widget frame})? cached = _frames[card.id];
    if (cached != null && cached.key == key) return cached.frame;
    final WindowContent content = card.content;
    final Widget frame = switch (content) {
      ToolWindow tw => _toolCardFrame(card, tw, slot: slot, group: group),
      SystemWindow sw => _systemCardFrame(card, sw, slot: slot),
    };
    _frames[card.id] = (key: key, frame: frame);
    return frame;
  }

  Widget _toolBody(CanvasCard card, UtilityDescriptor descriptor) {
    final LinkChannel? channel = _c.channelForCard(card.id);
    final _ToolBodyCacheEntry? cached = _toolBodies[card.id];
    if (cached != null &&
        identical(cached.descriptor, descriptor) &&
        cached.seed == card.seed &&
        identical(cached.inbound, channel?.inbound)) {
      return cached.body;
    }
    final Widget body = PipeScope(
      cardId: card.id,
      child: descriptor.builder(
        context,
        initialInput: card.seed,
        seedSource: card.seed != null ? SeedSource.paste : SeedSource.none,
        onSwitchTool: (UtilityDescriptor u, String input) =>
            _c.openTool(u, seed: input),
        actionBar: null,
        link: channel,
      ),
    );
    _toolBodies[card.id] = (
      descriptor: descriptor,
      seed: card.seed,
      inbound: channel?.inbound,
      body: body,
    );
    return body;
  }

  void _onTitleDrag(int id, Offset d) {
    if (_draggingCardId.value != id) _draggingCardId.value = id;
    _c.moveBy(id, d.dx, d.dy);
  }

  void _onTitleDragEnd(int id) {
    _draggingCardId.value = null;
    final CanvasCard? card = _cardById(id);
    if (card != null) _onMoveEnd(card);
  }

  Widget _systemCardFrame(
    CanvasCard card,
    SystemWindow sw, {
    required int slot,
  }) {
    final Widget body = switch (sw.app) {
      SystemApp.history => const HistoryBody(),
      SystemApp.settings => const SettingsBody(desktopShellOverride: true),
    };
    return ToolCardFrame(
      title: sw.title,
      slot: slot <= 9 ? slot : null,
      focused: _c.focusedId == card.id,
      maximized: card.maximized,
      height: card.height,
      scrollBody: false,
      onFocus: () => _c.focus(card.id),
      onClose: () => _c.close(card.id),
      onMinimize: () => _c.minimize(card.id),
      onToggleMaximize: () => _toggleMax(card),
      onMoveDelta: (Offset d) => _onTitleDrag(card.id, d),
      onMoveEnd: () => _onTitleDragEnd(card.id),
      onResizeEdge:
          (
            double dx,
            double dy, {
            required bool left,
            required bool right,
            required bool top,
            required bool bottom,
            required double measuredHeight,
          }) {
            _c.resizeEdge(
              card.id,
              dx: dx,
              dy: dy,
              left: left,
              right: right,
              top: top,
              bottom: bottom,
              measuredHeight: measuredHeight,
            );
          },
      onResizeEnd: _c.commit,
      onSecondaryTapDown: (TapDownDetails details) =>
          _showWindowContextMenuFor(details.globalPosition, card.id),
      child: body,
    );
  }

  Widget _toolCardFrame(
    CanvasCard card,
    ToolWindow tw, {
    required int slot,
    required LinkGroup? group,
  }) {
    final UtilityDescriptor descriptor = tw.descriptor;
    final ({String partnerId, ContentType type})? partner =
        _linkPartners[descriptor.id];
    final bool linked = group != null;
    final ToolCardFrame frame = ToolCardFrame(
      title: tw.title,
      slot: slot <= 9 ? slot : null,
      focused: _c.focusedId == card.id,
      maximized: card.maximized,
      height: card.height,
      onFocus: () => _c.focus(card.id),
      onClose: () => _c.close(card.id),
      onMinimize: () => _c.minimize(card.id),
      onToggleMaximize: () => _toggleMax(card),
      onDuplicate: () => _c.duplicate(card.id),
      onMoveDelta: (Offset d) => _onTitleDrag(card.id, d),
      onMoveEnd: () => _onTitleDragEnd(card.id),
      onResizeEdge:
          (
            double dx,
            double dy, {
            required bool left,
            required bool right,
            required bool top,
            required bool bottom,
            required double measuredHeight,
          }) {
            _c.resizeEdge(
              card.id,
              dx: dx,
              dy: dy,
              left: left,
              right: right,
              top: top,
              bottom: bottom,
              measuredHeight: measuredHeight,
            );
          },
      onResizeEnd: _c.commit,
      linked: linked,
      linkTooltip: linked
          ? 'Unlink'
          : partner == null
          ? null
          : 'Open linked ${UtilityCatalog.byId(partner.partnerId).name}',
      onLink: (linked || partner != null)
          ? () => _toggleLink(card, partner)
          : null,
      onSecondaryTapDown: (TapDownDetails details) =>
          _showWindowContextMenuFor(details.globalPosition, card.id),
      child: _toolBody(card, descriptor),
    );
    return DragTarget<PipePayload>(
      onWillAcceptWithDetails: (DragTargetDetails<PipePayload> d) =>
          d.data.sourceCardId != card.id &&
          descriptor.inputSources.contains(UtilityInputSource.liveLink) &&
          descriptor.liveLinkTypes.contains(d.data.type),
      onAcceptWithDetails: (DragTargetDetails<PipePayload> d) => _c.linkCards(
        d.data.sourceCardId,
        card.id,
        type: d.data.type,
        seedCanonical: d.data.value,
      ),
      builder:
          (
            BuildContext context,
            List<PipePayload?> candidate,
            List<dynamic> rejected,
          ) => frame,
    );
  }

  /// Edge-snap threshold in logical pixels.
  static const double _snapThreshold = 16;

  void _onMoveEnd(CanvasCard card) {
    final Size? size = _canvasSize;
    if (size != null) {
      // Check edge-snap: left, right, top.
      if (card.x <= _snapThreshold) {
        _c.snap(
          card.id,
          x: 0,
          y: 0,
          width: size.width / 2,
          height: size.height,
        );
        return;
      }
      if (card.x + card.width >= size.width - _snapThreshold) {
        _c.snap(
          card.id,
          x: size.width / 2,
          y: 0,
          width: size.width / 2,
          height: size.height,
        );
        return;
      }
      if (card.y <= _snapThreshold) {
        _c.maximize(
          card.id,
          x: 0,
          y: 0,
          width: size.width,
          height: size.height,
        );
        return;
      }
    }
    _c.commit();
  }

  void _toggleMax(CanvasCard card) {
    final Size? size = _canvasSize;
    if (size == null) return;
    _c.toggleMaximize(
      card.id,
      x: 0,
      y: 0,
      width: size.width,
      height: size.height,
    );
  }

  Size? get _canvasSize {
    final RenderBox? box =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size;
  }

  /// Toggles the header link on [card]: unlinks if already linked (works even
  /// for a drop-linked card whose [partner] is null), otherwise opens its fixed
  /// [partner] tool as a new card and links the two. The source card's value
  /// seeds the group (the linkable body emits on attach).
  void _toggleLink(
    CanvasCard card,
    ({String partnerId, ContentType type})? partner,
  ) {
    if (_c.groupForCard(card.id) != null) {
      _c.unlinkCard(card.id);
      return;
    }
    if (partner == null) return;
    final int siblingId = _c.openTool(UtilityCatalog.byId(partner.partnerId));
    _c.linkCards(card.id, siblingId, type: partner.type);
  }

  /// One gold segment per linked pair, anchored at each card's title bar (in
  /// the same panned coordinates as the cards).
  List<({Offset a, Offset b})> _linkSegments(
    List<CanvasCard> cards,
    Offset pan,
  ) {
    final Map<int, CanvasCard> byId = <int, CanvasCard>{
      for (final CanvasCard card in cards) card.id: card,
    };
    final List<({Offset a, Offset b})> segments = <({Offset a, Offset b})>[];
    for (final LinkGroup g in _c.groups) {
      final List<CanvasCard> members = g.members
          .map((int id) => byId[id])
          .whereType<CanvasCard>()
          .toList();
      for (int i = 0; i + 1 < members.length; i++) {
        segments.add((
          a: _anchor(members[i], pan),
          b: _anchor(members[i + 1], pan),
        ));
      }
    }
    return segments;
  }

  Offset _anchor(CanvasCard card, Offset pan) =>
      Offset(card.x + pan.dx + card.width / 2, card.y + pan.dy + 18);

  void _showWallpaperContextMenu(BuildContext context, Offset position) {
    showDesktopContextMenu(context, position, <ContextMenuItem>[
      ContextMenuItem(
        label: 'New Window...  ⌘K',
        icon: MqIcons.plus,
        action: _openViaPalette,
      ),
      ContextMenuItem(
        label: 'Choose Wallpaper...',
        icon: MqIcons.setting,
        action: () => _c.openSystem(SystemApp.settings),
      ),
      ContextMenuItem(
        label: 'Clear Canvas',
        icon: MqIcons.trash,
        action: () => _c.closeAll(),
        destructive: true,
      ),
    ]);
  }

  /// Opens the window menu for card [id] with its latest record (the frame
  /// that received the click may be a cached instance).
  void _showWindowContextMenuFor(Offset position, int id) {
    final CanvasCard? card = _cardById(id);
    if (card != null) _showWindowContextMenu(context, position, card);
  }

  void _showWindowContextMenu(
    BuildContext context,
    Offset position,
    CanvasCard card,
  ) {
    final bool linked = _c.groupForCard(card.id) != null;
    final UtilityDescriptor? descriptor = card.toolDescriptor;
    final ({String partnerId, ContentType type})? partner = descriptor != null
        ? _linkPartners[descriptor.id]
        : null;

    showDesktopContextMenu(context, position, <ContextMenuItem>[
      ContextMenuItem(
        label: card.maximized ? 'Restore Window' : 'Maximize Window',
        icon: MqIcons.plus,
        action: () => _toggleMax(card),
      ),
      ContextMenuItem(
        label: 'Minimize Window',
        icon: MqIcons.minus,
        action: () => _c.minimize(card.id),
      ),
      if (descriptor != null) ...<ContextMenuItem>[
        ContextMenuItem(
          label: 'Duplicate Window  ⌥D',
          icon: MqIcons.copy,
          action: () => _c.duplicate(card.id),
        ),
        if (linked)
          ContextMenuItem(
            label: 'Unlink Sibling',
            icon: MqIcons.link,
            action: () => _c.unlinkCard(card.id),
          )
        else if (partner != null)
          ContextMenuItem(
            label: 'Open Linked ${UtilityCatalog.byId(partner.partnerId).name}',
            icon: MqIcons.link,
            action: () => _toggleLink(card, partner),
          ),
      ],
      ContextMenuItem(
        label: 'Close Window  Esc',
        icon: MqIcons.trash,
        action: () => _c.close(card.id),
        destructive: true,
      ),
    ]);
  }
}

/// Subtle dot grid that scrolls with the canvas pan, echoing the design mock.
class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color, required this.offset})
    : super(repaint: offset);

  final Color color;
  final ValueListenable<Offset> offset;

  static const double _step = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Offset pan = offset.value;
    final double startX = pan.dx % _step;
    final double startY = pan.dy % _step;
    for (double x = startX; x < size.width; x += _step) {
      for (double y = startY; y < size.height; y += _step) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.offset != offset || old.color != color;
}

/// Draws the gold tether between linked cards using orthogonal routing (at most 1 turnaround).
class _LinkLinePainter extends CustomPainter {
  _LinkLinePainter({required this.segments, required this.color});

  final List<({Offset a, Offset b})> segments;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final ({Offset a, Offset b}) s in segments) {
      final Path path = Path()
        ..moveTo(s.a.dx, s.a.dy)
        ..lineTo(s.b.dx, s.a.dy)
        ..lineTo(s.b.dx, s.b.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LinkLinePainter old) =>
      old.color != color || !listEquals(old.segments, segments);
}

class _AnimatedWindow extends StatelessWidget {
  const _AnimatedWindow({
    required this.card,
    required this.slot,
    required this.pan,
    required this.canvasSize,
    required this.child,
  });

  final CanvasCard card;
  final int slot;
  final Offset pan;
  final Size canvasSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isMini = card.minimized;
    final double targetX = canvasSize.width / 2 - card.width / 2;
    final double targetY = canvasSize.height - 40;

    final double x = isMini ? targetX : card.x;
    final double y = isMini ? targetY : card.y;
    final double scale = isMini ? 0.05 : 1.0;
    final double opacity = isMini ? 0.0 : 1.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: x + pan.dx,
      top: y + pan.dy,
      width: card.width,
      height: card.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity.clamp(0.0, 1.0),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          scale: scale,
          child: IgnorePointer(ignoring: isMini, child: child),
        ),
      ),
    );
  }
}
