import 'dart:async' show unawaited;
import 'dart:ui' as ui;

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
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/sensitive_data_policy.dart';
import '../../widgets/desktop/command_palette.dart';
import '../../widgets/desktop/desktop_icon_grid.dart';
import '../../widgets/desktop/link_identity.dart';
import '../../widgets/desktop/link_tag.dart';
import '../../widgets/desktop/links_panel.dart';
import '../../widgets/desktop/pipe.dart';
import '../../widgets/desktop/tool_card_frame.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
import '../../widgets/desktop/desktop_context_menu.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/desktop/shortcuts_hud.dart';

/// Header-toggle shortcuts (see docs/adr/0001): a card's link button opens
/// this fixed partner tool and links the two on one canonical type. Keyed by
/// tool id → its partner tool + the shared canonical type. Other linkable
/// tools open a target picker, while output-cell dragging remains available.
/// The canvas owns this; the bodies stay shell-agnostic.
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
  bool follower,
  Widget body,
});

typedef _LinkTargetChoice = ({
  UtilityDescriptor descriptor,
  ContentType type,
  int? cardId,
  bool suggested,
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
  bool _linkPickerOpen = false;
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

  /// Card id -> generation of its latest minimize/restore animation.
  final Map<int, int> _animatingMinimizedIds = <int, int>{};
  int _animationGeneration = 0;
  final Map<int, bool> _prevMinimized = <int, bool>{};

  /// Built once: the launcher grid depends on no canvas state, so reusing the
  /// instance keeps its ~30 tiles out of every canvas rebuild.
  late final Widget _iconGrid = RepaintBoundary(
    child: DesktopIconGrid(
      onOpen: (UtilityDescriptor u) => _c.openTool(u),
      onOpenSystem: (SystemApp app) => _c.openSystem(app),
    ),
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
        if (card.minimized != wasMinimized) {
          // A newer minimize/restore of the same card supersedes the pending
          // removal, so a quick toggle can't clear the flag mid-animation.
          final int generation = ++_animationGeneration;
          _animatingMinimizedIds[card.id] = generation;
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _animatingMinimizedIds[card.id] == generation) {
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

    if (k == LogicalKeyboardKey.escape && _linkPickerOpen) {
      final NavigatorState navigator = Navigator.of(
        context,
        rootNavigator: true,
      );
      if (navigator.canPop()) navigator.pop();
      return KeyEventResult.handled;
    }
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
                onWillAcceptWithDetails: (DragTargetDetails<PipePayload> d) =>
                    _cardById(d.data.sourceCardId) != null,
                onAcceptWithDetails: _onDropOnCanvas,
                builder:
                    (
                      BuildContext context,
                      List<PipePayload?> candidate,
                      List<dynamic> rejected,
                    ) {
                      final bool canOpen = candidate.any(
                        (PipePayload? payload) => payload != null,
                      );
                      final bool rejectedStaleSource = rejected.any(
                        (dynamic payload) =>
                            payload is PipePayload &&
                            _cardById(payload.sourceCardId) == null,
                      );
                      final Widget wallpaper = GestureDetector(
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
                      );
                      // Same Stack slot either way so the wallpaper subtree is
                      // not remounted when drag feedback appears.
                      if (!canOpen && !rejectedStaleSource) {
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[wallpaper],
                        );
                      }
                      final String feedback = canOpen
                          ? 'Release to open an unlinked tool. Drop on a window to create a live link.'
                          : 'Source window closed. Cancel this drag and try again.';
                      return Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          wallpaper,
                          Center(
                            child: IgnorePointer(
                              child: Semantics(
                                liveRegion: true,
                                label: feedback,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: context.mq.colors.surface,
                                    borderRadius: BorderRadius.circular(
                                      MqRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: rejectedStaleSource
                                          ? context.mq.colors.danger
                                          : context.mq.colors.accent,
                                    ),
                                    boxShadow: context.mq.colors.shadow,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: MqSpacing.md,
                                      vertical: MqSpacing.sm,
                                    ),
                                    child: Text(
                                      feedback,
                                      textAlign: TextAlign.center,
                                      style: MqTextStyles.caption1.copyWith(
                                        color: rejectedStaleSource
                                            ? context.mq.colors.danger
                                            : context.mq.colors.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
              ),
            ),
            Positioned.fill(child: _iconGrid),
            ListenableBuilder(
              listenable: _overlayListenable,
              builder: (BuildContext context, Widget? _) => _snapPreview(c),
            ),
            for (final CanvasCard card in zCards)
              if (!card.minimized ||
                  _animatingMinimizedIds.containsKey(card.id))
                _buildCardWrapper(
                  card: card,
                  openOrder: openOrder,
                  canvasSize: canvasSize ?? const Size(1200, 800),
                ),
            if (_c.hasLinks) ..._linkOverlay(context),
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
    if (_cardById(details.data.sourceCardId) == null) return;
    final List<DetectionMatch<Object?>> matches =
        DetectionPreferenceScope.read(context).rank(
          UtilityCatalog.detectArtifacts(
            details.data.value,
            provenance: ArtifactProvenance.liveLink,
          ),
        );
    if (matches.isEmpty) {
      unawaited(_showNoToolDrop());
      return;
    }
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

    if (_animatingMinimizedIds.containsKey(id)) {
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
    final String? linkedMemberKey = group == null
        ? null
        : (group.members.toList()..sort()).join(',');
    final LinkIdentity? identity = group == null
        ? null
        : linkIdentities(_c.groups, context.mq.colors)[group.id];
    final Object key = (
      card.content,
      slot,
      _c.focusedId == card.id,
      card.maximized,
      card.height,
      card.seed,
      group,
      linkedMemberKey,
      identity,
      group == null ? null : _c.isFollower(card.id),
    );
    final ({Object key, Widget frame})? cached = _frames[card.id];
    if (cached != null && cached.key == key) return cached.frame;
    final WindowContent content = card.content;
    // Each window is its own layer: moving it re-composites instead of
    // re-recording its content, shadow and clip.
    final Widget frame = RepaintBoundary(
      child: switch (content) {
        ToolWindow tw => _toolCardFrame(
          card,
          tw,
          slot: slot,
          group: group,
          identity: identity,
        ),
        SystemWindow sw => _systemCardFrame(card, sw, slot: slot),
      },
    );
    _frames[card.id] = (key: key, frame: frame);
    return frame;
  }

  Widget _toolBody(CanvasCard card, UtilityDescriptor descriptor) {
    final LinkChannel? channel = _c.channelForCard(card.id);
    final bool follower = _c.isFollower(card.id);
    final _ToolBodyCacheEntry? cached = _toolBodies[card.id];
    if (cached != null &&
        identical(cached.descriptor, descriptor) &&
        cached.seed == card.seed &&
        cached.follower == follower &&
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
      follower: follower,
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
      SystemApp.links => LinksPanel(controller: _c),
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
    required LinkIdentity? identity,
  }) {
    final UtilityDescriptor descriptor = tw.descriptor;
    final ({String partnerId, ContentType type})? partner =
        _linkPartners[descriptor.id];
    final bool linked = group != null;
    final bool linkable = _isLinkable(descriptor);
    final bool follower = group != null && _c.isFollower(card.id);
    final String? linkedNames = group == null
        ? null
        : _linkedMemberNames(card, group);
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
      linkTooltip: linked ? 'Unlink' : 'Choose live link target',
      linkHint: linked
          ? follower
                ? 'Link group ${identity?.letter ?? ''}. Follows ${linkedNames ?? 'other windows'}. Tap to unlink this window.'
                : 'Link group ${identity?.letter ?? ''}, two-way with ${linkedNames ?? 'other windows'}. Tap to unlink this window.'
          : partner != null
          ? 'Choose a window to link; ${UtilityCatalog.byId(partner.partnerId).name} is suggested.'
          : 'Choose an open window or a new tool to link. Drag an output cell onto another window to link it directly.',
      linkStatus: linked
          ? '${identity?.letter ?? ''}${follower ? ' · follows' : ''}'
          : null,
      linkColor: identity?.color,
      onLink: linked
          ? () => _c.unlinkCard(card.id)
          : !linkable
          ? null
          : () => _showLinkPicker(card, partner: partner),
      onSecondaryTapDown: (TapDownDetails details) =>
          _showWindowContextMenuFor(details.globalPosition, card.id),
      child: _toolBody(card, descriptor),
    );
    return DragTarget<PipePayload>(
      onWillAcceptWithDetails: (DragTargetDetails<PipePayload> d) =>
          _c.linkIssueFor(d.data.sourceCardId, card.id, type: d.data.type) ==
          null,
      onAcceptWithDetails: (DragTargetDetails<PipePayload> d) {
        final int? result = _c.linkCards(
          d.data.sourceCardId,
          card.id,
          type: d.data.type,
          seedCanonical: d.data.value,
          targetFollows: true,
        );
        if (result == null) {
          final LinkIssue issue =
              _c.linkIssueFor(
                d.data.sourceCardId,
                card.id,
                type: d.data.type,
              ) ??
              LinkIssue.targetMissing;
          unawaited(_showLinkIssue(issue, d.data.type));
        }
      },
      builder:
          (
            BuildContext context,
            List<PipePayload?> candidate,
            List<dynamic> rejected,
          ) {
            PipePayload? acceptedPayload;
            for (final PipePayload? payload in candidate) {
              if (payload != null) {
                acceptedPayload = payload;
                break;
              }
            }
            PipePayload? rejectedPayload;
            for (final dynamic payload in rejected) {
              if (payload is PipePayload) {
                rejectedPayload = payload;
                break;
              }
            }
            final bool canLink = acceptedPayload != null;
            final PipePayload? payload = acceptedPayload ?? rejectedPayload;
            final String? feedback = payload == null
                ? null
                : canLink
                ? 'Release to follow · ${contentTypeLabel(payload.type)}'
                : (_c.linkIssueFor(
                            payload.sourceCardId,
                            card.id,
                            type: payload.type,
                          ) ??
                          LinkIssue.targetUnsupported)
                      .message(payload.type);
            // Always return the frame inside the same Stack slot: swapping
            // between a bare frame and a wrapped one changes the tree shape and
            // remounts the window's body, wiping its local state mid-drag.
            if (feedback == null) {
              return Stack(clipBehavior: Clip.none, children: <Widget>[frame]);
            }
            final Color feedbackColor = canLink
                ? context.mq.colors.accent
                : context.mq.colors.danger;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                frame,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: feedback,
                      child: Stack(
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              color: feedbackColor.withValues(alpha: 0.05),
                              border: Border.all(
                                color: feedbackColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(MqRadius.md),
                            ),
                          ),
                          Positioned(
                            top: 42,
                            left: 8,
                            right: 8,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.mq.colors.surface,
                                  borderRadius: BorderRadius.circular(
                                    MqRadius.sm,
                                  ),
                                  border: Border.all(
                                    color: feedbackColor,
                                    width: 0.75,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: MqSpacing.sm,
                                    vertical: MqSpacing.xs,
                                  ),
                                  child: Text(
                                    feedback,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: MqTextStyles.caption1.copyWith(
                                      color: feedbackColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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

  /// Quick path for a paired tool: opens its fixed [partner] tool as a new
  /// window beside [card] and links the two (two-way). The source card's value
  /// seeds the group (the linkable body emits on attach).
  void _openPartner(
    CanvasCard card,
    ({String partnerId, ContentType type}) partner,
  ) {
    final int siblingId = _c.openTool(UtilityCatalog.byId(partner.partnerId));
    _placeBeside(card.id, siblingId);
    if (_c.linkCards(card.id, siblingId, type: partner.type) == null) {
      final LinkIssue issue =
          _c.linkIssueFor(card.id, siblingId, type: partner.type) ??
          LinkIssue.sourceMissing;
      _c.close(siblingId);
      unawaited(_showLinkIssue(issue, partner.type));
    }
  }

  /// Moves the newly opened [newId] next to [sourceId]: right of it when that
  /// fits the canvas, else left of it, else leaves the cascade position.
  void _placeBeside(int sourceId, int newId) {
    final Size? size = _canvasSize;
    final CanvasCard? source = _cardById(sourceId);
    final CanvasCard? fresh = _cardById(newId);
    if (size == null || source == null || fresh == null) return;
    const double gap = 24;
    // Card coordinates are pre-pan; the visible span is [-pan, -pan + width].
    final double visibleLeft = -_pan.value.dx;
    final double visibleRight = visibleLeft + size.width;
    final double right = source.x + source.width + gap;
    if (right + fresh.width <= visibleRight) {
      _c.moveTo(newId, right, source.y);
      return;
    }
    final double left = source.x - gap - fresh.width;
    if (left >= visibleLeft) _c.moveTo(newId, left, source.y);
  }

  bool _isLinkable(UtilityDescriptor descriptor) => descriptor.supportsLiveLink;

  String? _linkedMemberNames(CanvasCard card, LinkGroup group) {
    final Set<String> names = group.members
        .where((int id) => id != card.id)
        .map((int id) => _cardById(id)?.toolDescriptor?.name)
        .whereType<String>()
        .toSet();
    return names.isEmpty ? null : names.join(', ');
  }

  Future<void> _showLinkPicker(
    CanvasCard source, {
    ({String partnerId, ContentType type})? partner,
  }) async {
    final UtilityDescriptor? sourceDescriptor = source.toolDescriptor;
    if (sourceDescriptor == null || !_isLinkable(sourceDescriptor)) return;

    final List<_LinkTargetChoice> openChoices = <_LinkTargetChoice>[];
    final List<_LinkTargetChoice> newChoices = <_LinkTargetChoice>[];
    final Set<String> blockedTargets = <String>{};
    final LinkGroup? sourceGroup = _c.groupForCard(source.id);
    final bool sourceFollowsOnly =
        sourceDescriptor.linkCapability == LinkCapability.followOnly;
    // A follow-only source follows its target, so the target must be able to
    // send.
    bool canPair(UtilityDescriptor t) =>
        !sourceFollowsOnly || t.linkCapability != LinkCapability.followOnly;
    for (final CanvasCard target in _c.cards) {
      if (target.id == source.id) continue;
      final UtilityDescriptor? targetDescriptor = target.toolDescriptor;
      if (targetDescriptor == null || !canPair(targetDescriptor)) continue;
      final LinkGroup? targetGroup = _c.groupForCard(target.id);
      final ContentType? type = _c.defaultLinkType(
        sourceDescriptor,
        targetDescriptor,
        sourceGroup: sourceGroup,
        targetGroup: targetGroup,
      );
      if (type == null) {
        // Blocked only when the tools could link but the target's group is
        // locked to another type.
        final bool shared = sourceDescriptor.liveLinkTypes.any(
          targetDescriptor.liveLinkTypes.contains,
        );
        if (shared && targetGroup != null) {
          blockedTargets.add(
            '${targetDescriptor.name} (${contentTypeLabel(targetGroup.type)})',
          );
        }
        continue;
      }
      if (_c.linkIssueFor(source.id, target.id, type: type) != null) continue;
      openChoices.add((
        descriptor: targetDescriptor,
        type: type,
        cardId: target.id,
        suggested: partner?.partnerId == targetDescriptor.id,
      ));
    }
    for (final UtilityDescriptor target in UtilityCatalog.all) {
      if (!_isLinkable(target) || !canPair(target)) continue;
      final ContentType? type = _c.defaultLinkType(
        sourceDescriptor,
        target,
        sourceGroup: sourceGroup,
      );
      if (type == null) continue;
      if (type == ContentType.text &&
          target.linkCapability != LinkCapability.sourceOnly &&
          sourceDescriptor.linkCapability != LinkCapability.followOnly &&
          !target.linkAcceptsTextShapes.contains(
            sourceDescriptor.linkTextShape,
          )) {
        continue;
      }
      newChoices.add((
        descriptor: target,
        type: type,
        cardId: null,
        suggested: partner?.partnerId == target.id,
      ));
    }
    // The suggested partner leads its section.
    for (final List<_LinkTargetChoice> list in <List<_LinkTargetChoice>>[
      openChoices,
      newChoices,
    ]) {
      final int at = list.indexWhere((_LinkTargetChoice c) => c.suggested);
      if (at > 0) list.insert(0, list.removeAt(at));
    }
    final bool empty = openChoices.isEmpty && newChoices.isEmpty;

    final String explanation = empty
        ? 'No compatible target is available. Try dragging an output onto a window that supports the same value type.'
        : sourceFollowsOnly
        ? '${sourceDescriptor.name} only displays what it receives, so it follows the window you pick.'
        : 'Linked windows share one value. Followers only receive it.';
    final String sourceBlockedNote = sourceGroup == null
        ? ''
        : '\n\nThis window is already linked as ${contentTypeLabel(sourceGroup.type)}. Unlink it before choosing another type.';
    final String targetBlockedNote = blockedTargets.isEmpty
        ? ''
        : blockedTargets.length == 1
        ? '\n\n${blockedTargets.single} already uses another link type. Unlink it before joining.'
        : '\n\n${blockedTargets.join(', ')} already use another link type. Unlink them before joining.';

    final Map<int, LinkIdentity> identities = linkIdentities(
      _c.groups,
      context.mq.colors,
    );
    final List<CanvasCard> openOrder = _c.cards;
    bool targetFollows = false;

    _linkPickerOpen = true;
    _LinkTargetChoice? choice;
    try {
      choice = await showCupertinoModalPopup<_LinkTargetChoice>(
        context: context,
        builder: (BuildContext sheetContext) => CupertinoActionSheet(
          title: Text(
            '${sourceFollowsOnly ? 'Follow' : 'Link'} ${sourceDescriptor.name}',
          ),
          message: StatefulBuilder(
            builder: (BuildContext context, StateSetter setSheetState) =>
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('$explanation$sourceBlockedNote$targetBlockedNote'),
                    if (!empty && !sourceFollowsOnly) ...<Widget>[
                      const SizedBox(height: MqSpacing.md),
                      _followToggle(
                        context,
                        label: 'Target follows ${sourceDescriptor.name}',
                        value: targetFollows,
                        onChanged: (bool v) =>
                            setSheetState(() => targetFollows = v),
                      ),
                    ],
                  ],
                ),
          ),
          actions: <Widget>[
            if (openChoices.isNotEmpty) ...<Widget>[
              _pickerHeader(sheetContext, 'Open windows'),
              for (final _LinkTargetChoice target in openChoices)
                _linkTargetAction(
                  sheetContext,
                  target,
                  identities: identities,
                  slot:
                      openOrder.indexWhere(
                        (CanvasCard c) => c.id == target.cardId,
                      ) +
                      1,
                ),
            ],
            if (newChoices.isNotEmpty) ...<Widget>[
              _pickerHeader(sheetContext, 'New window'),
              for (final _LinkTargetChoice target in newChoices)
                _linkTargetAction(
                  sheetContext,
                  target,
                  identities: identities,
                  slot: 0,
                ),
            ],
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    } finally {
      _linkPickerOpen = false;
    }
    if (choice == null || !mounted) return;
    await _applyLinkChoice(source, choice, targetFollows: targetFollows);
  }

  Widget _pickerHeader(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: MqSpacing.md,
      vertical: MqSpacing.sm,
    ),
    child: Text(
      label,
      style: MqTextStyles.monoSm.copyWith(color: context.mq.colors.textSec),
    ),
  );

  Widget _followToggle(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final MqColors c = context.mq.colors;
    return Semantics(
      label: label,
      checked: value,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              value
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              size: 20,
              color: value ? c.accent : c.textSec,
            ),
            const SizedBox(width: MqSpacing.sm),
            Text(label),
          ],
        ),
      ),
    );
  }

  /// One picker row: tool icon + name, tagged with its open slot, a
  /// suggestion mark, and the target's group when linked.
  Widget _linkTargetAction(
    BuildContext sheetContext,
    _LinkTargetChoice target, {
    required Map<int, LinkIdentity> identities,
    required int slot,
  }) {
    final MqColors c = sheetContext.mq.colors;
    final bool isOpen = target.cardId != null;
    final String? availability = !isOpen
        ? null
        : slot >= 1 && slot <= 9
        ? 'Open · ⌥$slot'
        : 'Open';
    final LinkGroup? targetGroup = isOpen
        ? _c.groupForCard(target.cardId!)
        : null;
    final LinkIdentity? groupIdentity = targetGroup == null
        ? null
        : identities[targetGroup.id];
    final String name = target.descriptor.name;
    final String? roleTag = switch (target.descriptor.linkCapability) {
      LinkCapability.followOnly => 'Follows',
      LinkCapability.sourceOnly => 'Sends only',
      LinkCapability.twoWay => null,
    };
    final String semantic = <String>[
      '${isOpen ? 'Link to' : 'Open'} $name',
      if (target.suggested) 'Suggested',
      ?availability,
      ?roleTag,
      if (groupIdentity != null) 'in link group ${groupIdentity.letter}',
    ].join(', ');
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.of(sheetContext).pop(target),
      child: Semantics(
        label: semantic,
        excludeSemantics: true,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.xs,
          children: <Widget>[
            Icon(target.descriptor.icon, size: 18, color: c.textSec),
            Text(isOpen ? 'Link to $name' : 'Open $name'),
            if (target.suggested) const LinkTag(label: 'Suggested'),
            if (availability != null) LinkTag(label: availability),
            if (roleTag != null) LinkTag(label: roleTag),
            if (groupIdentity != null)
              LinkTag(label: groupIdentity.letter, color: groupIdentity.color),
          ],
        ),
      ),
    );
  }

  Future<void> _applyLinkChoice(
    CanvasCard source,
    _LinkTargetChoice choice, {
    required bool targetFollows,
  }) async {
    if (_cardById(source.id) == null) {
      await _showLinkIssue(LinkIssue.sourceMissing, choice.type);
      return;
    }
    final bool openedTarget = choice.cardId == null;
    final int targetId = choice.cardId ?? _c.openTool(choice.descriptor);
    if (openedTarget) _placeBeside(source.id, targetId);
    final LinkIssue? issue = _c.linkIssueFor(
      source.id,
      targetId,
      type: choice.type,
    );
    if (issue != null) {
      if (openedTarget) _c.close(targetId);
      await _showLinkIssue(issue, choice.type);
      return;
    }
    if (_c.linkCards(
          source.id,
          targetId,
          type: choice.type,
          targetFollows: targetFollows,
        ) ==
        null) {
      if (openedTarget) _c.close(targetId);
      final LinkIssue issue =
          _c.linkIssueFor(source.id, targetId, type: choice.type) ??
          LinkIssue.alreadyLinked;
      await _showLinkIssue(issue, choice.type);
    }
  }

  Future<void> _showLinkIssue(LinkIssue issue, ContentType type) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Couldn’t link windows'),
        content: Text(issue.message(type)),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoToolDrop() async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('No tool found for this value'),
        content: const Text(
          'Keep it in the source window, or drop the output onto a compatible window to create a live link.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Hub star per group: every member's title-bar anchor, plus the centroid
  /// they all tether to (canonical-hub model, docs/adr/0001). Pan coordinates,
  /// like the cards.
  List<_LinkHub> _linkHubs(
    List<CanvasCard> cards,
    Offset pan,
    Map<int, LinkIdentity> identities,
  ) {
    final Map<int, CanvasCard> byId = <int, CanvasCard>{
      for (final CanvasCard card in cards) card.id: card,
    };
    final List<_LinkHub> hubs = <_LinkHub>[];
    for (final LinkGroup g in _c.groups) {
      final LinkIdentity? identity = identities[g.id];
      if (identity == null) continue;
      final List<CanvasCard> members = g.members
          .map((int id) => byId[id])
          .whereType<CanvasCard>()
          .where((CanvasCard card) => !card.minimized)
          .toList();
      if (members.isEmpty) continue;
      final List<Offset> anchors = <Offset>[
        for (final CanvasCard m in members) _anchor(m, pan),
      ];
      // The hub sits on a row just above the highest member, so tethers rise
      // from each window's top edge and meet over the windows, never across a
      // title bar.
      double sumX = 0;
      double top = double.infinity;
      for (final Offset a in anchors) {
        sumX += a.dx;
        if (a.dy < top) top = a.dy;
      }
      hubs.add(
        _LinkHub(
          group: g,
          identity: identity,
          anchors: anchors,
          followers: <bool>[
            for (final CanvasCard m in members) _c.isFollower(m.id),
          ],
          hub: Offset(
            sumX / anchors.length,
            (top - _hubRise).clamp(_hubMinY, double.infinity),
          ),
        ),
      );
    }
    return hubs;
  }

  /// Tethers and hub chips, painted above the windows. The tethers never take
  /// hits; each chip is tappable and focuses its group's top-most member.
  List<Widget> _linkOverlay(BuildContext context) {
    final Map<int, LinkIdentity> identities = linkIdentities(
      _c.groups,
      context.mq.colors,
    );
    return <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: ListenableBuilder(
            listenable: _overlayListenable,
            builder: (BuildContext context, Widget? _) => CustomPaint(
              painter: _LinkLinePainter(
                hubs: _linkHubs(_c.cards, _pan.value, identities),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: ListenableBuilder(
          listenable: _overlayListenable,
          builder: (BuildContext context, Widget? _) => Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final _LinkHub h in _linkHubs(
                _c.cards,
                _pan.value,
                identities,
              ))
                Positioned(
                  key: ValueKey<int>(h.group.id),
                  left: h.hub.dx,
                  top: h.hub.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: _LinkHubChip(
                      group: h.group,
                      identity: h.identity,
                      sensitive: _c.groupIsSensitive(h.group),
                      onTap: () => _focusTopMember(h.group),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  void _focusTopMember(LinkGroup group) {
    for (final CanvasCard card in _c.cardsByZ.reversed) {
      if (group.members.contains(card.id) && !card.minimized) {
        _c.focus(card.id);
        return;
      }
    }
  }

  static const double _hubRise = 22;
  static const double _hubMinY = 14;

  /// Top-edge midpoint of [card], in panned coordinates.
  Offset _anchor(CanvasCard card, Offset pan) =>
      Offset(card.x + pan.dx + card.width / 2, card.y + pan.dy);

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
        if (linked && !_c.followFixed(card.id) && _c.isFollower(card.id))
          ContextMenuItem(
            label: '✓ Follow Only',
            icon: MqIcons.link,
            action: () => _c.setFollower(card.id, false),
          )
        else if (linked && !_c.followFixed(card.id) && _c.canFollow(card.id))
          ContextMenuItem(
            label: 'Follow Only',
            icon: MqIcons.link,
            action: () => _c.setFollower(card.id, true),
          ),
        if (linked)
          ContextMenuItem(
            label: 'Unlink Sibling',
            icon: MqIcons.link,
            action: () => _c.unlinkCard(card.id),
          ),
        if (linked)
          ContextMenuItem(
            label: 'Show Links',
            icon: MqIcons.link,
            action: () => _c.openSystem(SystemApp.links),
          )
        else if (_isLinkable(descriptor)) ...<ContextMenuItem>[
          if (partner != null)
            ContextMenuItem(
              label:
                  'Open Linked ${UtilityCatalog.byId(partner.partnerId).name}',
              icon: MqIcons.link,
              action: () => _openPartner(card, partner),
            ),
          ContextMenuItem(
            label: 'Choose Link Target…',
            icon: MqIcons.link,
            action: () => _showLinkPicker(card, partner: partner),
          ),
        ],
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

  static const double _radius = 0.75;

  // Dot lattice for the last painted size, one extra step on each axis so a
  // pan can be applied with a translate instead of rebuilding the points.
  static Size? _cachedSize;
  static Float32List? _cachedPoints;

  static Float32List _points(Size size) {
    if (_cachedSize == size) return _cachedPoints!;
    final int cols = (size.width / _step).ceil() + 1;
    final int rows = (size.height / _step).ceil() + 1;
    final Float32List points = Float32List(cols * rows * 2);
    int i = 0;
    for (int cx = 0; cx < cols; cx++) {
      for (int cy = 0; cy < rows; cy++) {
        points[i++] = cx * _step;
        points[i++] = cy * _step;
      }
    }
    _cachedSize = size;
    return _cachedPoints = points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _radius * 2;
    final Offset pan = offset.value;
    // Same phase as before: dots at (pan % step) + k * step, kept inside size.
    canvas.save();
    canvas.translate(pan.dx % _step, pan.dy % _step);
    canvas.drawRawPoints(ui.PointMode.points, _points(size), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.offset != offset || old.color != color;
}

class _LinkHub {
  const _LinkHub({
    required this.group,
    required this.identity,
    required this.anchors,
    required this.followers,
    required this.hub,
  });

  final LinkGroup group;
  final LinkIdentity identity;
  final List<Offset> anchors;

  /// Parallel to [anchors]: whether each member's window only follows.
  final List<bool> followers;
  final Offset hub;

  @override
  bool operator ==(Object other) =>
      other is _LinkHub &&
      other.group == group &&
      other.identity == identity &&
      other.hub == hub &&
      listEquals(other.anchors, anchors) &&
      listEquals(other.followers, followers);

  @override
  int get hashCode =>
      Object.hash(group, identity, hub, anchors.length, followers.length);
}

/// Draws each group's hub star: one orthogonal (at most one turn) tether per
/// member rising from its top-edge anchor to the hub row, then across to the
/// hub, in the group color.
class _LinkLinePainter extends CustomPainter {
  _LinkLinePainter({required this.hubs});

  final List<_LinkHub> hubs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _LinkHub h in hubs) {
      final Paint paint = Paint()
        ..color = h.identity.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final Paint fill = Paint()..color = h.identity.color;
      for (int i = 0; i < h.anchors.length; i++) {
        final Offset a = h.anchors[i];
        final Path path = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx, h.hub.dy)
          ..lineTo(h.hub.dx, h.hub.dy);
        canvas.drawPath(path, paint);
        if (h.followers[i]) {
          // Follower: head on the window edge, pointing into it.
          canvas.drawPath(_arrowhead(a, 1), fill);
        } else {
          canvas.drawCircle(a, 3, fill);
        }
      }
    }
  }

  /// Filled triangle with its tip at [tip], pointing along [dir] (-1 up,
  /// 1 down) on the vertical axis.
  static Path _arrowhead(Offset tip, double dir) => Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(tip.dx - 4.5, tip.dy - dir * 8)
    ..lineTo(tip.dx + 4.5, tip.dy - dir * 8)
    ..close();

  @override
  bool shouldRepaint(_LinkLinePainter old) => !listEquals(old.hubs, hubs);
}

/// Hub label: group letter, content type, and the live canonical value
/// (masked for sensitive groups). Listens to the group's canonical so only
/// the chip rebuilds on an emit.
class _LinkHubChip extends StatelessWidget {
  const _LinkHubChip({
    required this.group,
    required this.identity,
    required this.sensitive,
    required this.onTap,
  });

  final LinkGroup group;
  final LinkIdentity identity;
  final bool sensitive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MqColors c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.sm,
          vertical: MqSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MqRadius.md),
          border: Border.all(color: identity.color, width: 1),
          boxShadow: c.shadow,
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: group.canonical,
          builder: (BuildContext context, String canonical, Widget? _) {
            final String preview = SensitiveDataPolicy.safePreview(
              canonical,
              max: 24,
              sensitive: sensitive,
            );
            final String label =
                '${identity.letter} · ${contentTypeLabel(group.type)}';
            return Semantics(
              label:
                  'Link group ${identity.letter}, ${contentTypeLabel(group.type)}',
              value: preview,
              excludeSemantics: true,
              child: Text(
                preview.isEmpty ? label : '$label · $preview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MqTextStyles.monoSm.copyWith(color: identity.color),
              ),
            );
          },
        ),
      ),
    );
  }
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
