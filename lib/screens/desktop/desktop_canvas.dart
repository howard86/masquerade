import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../state/canvas_controller.dart';
import '../../state/link_group.dart';
import '../../state/window_content.dart';
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

/// Which canonical [ContentType]s a tool's card can RECEIVE via a pipe drop.
/// A cell→card drop links the two cards iff the target tool's set contains the
/// dragged payload's type. Phase 6 extends this as more link pairs land.
const Map<String, Set<ContentType>> _linkableTypes = <String, Set<ContentType>>{
  'base64': <ContentType>{ContentType.text},
  'json': <ContentType>{ContentType.text},
  'number_base': <ContentType>{ContentType.number},
  'math': <ContentType>{ContentType.number, ContentType.epoch},
  'timestamp': <ContentType>{ContentType.epoch, ContentType.number},
  'list': <ContentType>{ContentType.lines, ContentType.text},
  'diff': <ContentType>{ContentType.text, ContentType.lines},
  'color': <ContentType>{ContentType.color, ContentType.text},
};

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

  /// Anchors the canvas surface so a pipe drop's global offset can be mapped to
  /// canvas-local coordinates (drop − surfaceTopLeft − pan).
  final GlobalKey _surfaceKey = GlobalKey();
  Offset _pan = Offset.zero;

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

  int? _draggingCardId;
  final Set<int> _animatingMinimizedIds = <int>{};
  final Map<int, bool> _prevMinimized = <int, bool>{};

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    for (final card in _c.cards) {
      _prevMinimized[card.id] = card.minimized;
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _focusNode.dispose();
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

    CanvasCard? draggingCard;
    if (_draggingCardId != null) {
      for (final CanvasCard card in openOrder) {
        if (card.id == _draggingCardId) {
          draggingCard = card;
          break;
        }
      }
    }

    Rect? previewRect;
    final Size? canvasSize = _canvasSize;
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
                          setState(() => _pan += d.delta),
                      onSecondaryTapDown: (TapDownDetails details) =>
                          _showWallpaperContextMenu(
                            context,
                            details.globalPosition,
                          ),
                      child: CustomPaint(
                        painter: _DotGridPainter(color: c.border, offset: _pan),
                      ),
                    ),
              ),
            ),
            Positioned.fill(
              child: DesktopIconGrid(
                onOpen: (UtilityDescriptor u) => _c.openTool(u),
                onOpenSystem: (SystemApp app) => _c.openSystem(app),
              ),
            ),
            if (_c.hasLinks)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LinkLinePainter(
                      segments: _linkSegments(openOrder),
                      color: c.warning,
                    ),
                  ),
                ),
              ),
            if (previewRect != null)
              Positioned(
                left: previewRect.left + _pan.dx,
                top: previewRect.top + _pan.dy,
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

  void _onDropOnCanvas(DragTargetDetails<PipePayload> details) {
    final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(
      details.data.value,
    );
    if (matches.isEmpty) return;
    final RenderBox? box =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(details.offset);
    final int id = _c.openTool(matches.first, seed: details.data.value);
    _c.moveTo(id, local.dx - _pan.dx, local.dy - _pan.dy);
    _c.commit();
  }

  Widget _buildCardWrapper({
    required CanvasCard card,
    required List<CanvasCard> openOrder,
    required Size canvasSize,
  }) {
    final int slot = openOrder.indexWhere((c) => c.id == card.id) + 1;
    final Widget frame = _cardFrame(card, slot: slot);

    if (_animatingMinimizedIds.contains(card.id)) {
      return _AnimatedWindow(
        card: card,
        slot: slot,
        pan: _pan,
        canvasSize: canvasSize,
        child: frame,
      );
    }

    return Positioned(
      key: ValueKey<int>(card.id),
      left: card.x + _pan.dx,
      top: card.y + _pan.dy,
      child: SizedBox(width: card.width, height: card.height, child: frame),
    );
  }

  Widget _cardFrame(CanvasCard card, {required int slot}) {
    final WindowContent content = card.content;
    return switch (content) {
      ToolWindow tw => _toolCardFrame(card, tw, slot: slot),
      SystemWindow sw => _systemCardFrame(card, sw, slot: slot),
    };
  }

  Widget _systemCardFrame(
    CanvasCard card,
    SystemWindow sw, {
    required int slot,
  }) {
    final Widget body = switch (sw.app) {
      SystemApp.history => const HistoryBody(),
      SystemApp.settings => SettingsBody(isWebOverride: true),
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
      onMoveDelta: (Offset d) {
        if (_draggingCardId != card.id) {
          setState(() {
            _draggingCardId = card.id;
          });
        }
        _c.moveTo(card.id, card.x + d.dx, card.y + d.dy);
      },
      onMoveEnd: () {
        setState(() {
          _draggingCardId = null;
        });
        _onMoveEnd(card);
      },
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
          _showWindowContextMenu(context, details.globalPosition, card),
      child: body,
    );
  }

  Widget _toolCardFrame(CanvasCard card, ToolWindow tw, {required int slot}) {
    final UtilityDescriptor descriptor = tw.descriptor;
    final SeedSource src = card.seed != null
        ? SeedSource.paste
        : SeedSource.none;
    final ({String partnerId, ContentType type})? partner =
        _linkPartners[descriptor.id];
    final bool linked = _c.groupForCard(card.id) != null;
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
      onMoveDelta: (Offset d) {
        if (_draggingCardId != card.id) {
          setState(() {
            _draggingCardId = card.id;
          });
        }
        _c.moveTo(card.id, card.x + d.dx, card.y + d.dy);
      },
      onMoveEnd: () {
        setState(() {
          _draggingCardId = null;
        });
        _onMoveEnd(card);
      },
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
          _showWindowContextMenu(context, details.globalPosition, card),
      child: PipeScope(
        cardId: card.id,
        child: descriptor.builder(
          context,
          initialInput: card.seed,
          seedSource: src,
          onSwitchTool: (UtilityDescriptor u, String input) =>
              _c.openTool(u, seed: input),
          actionBar: null,
          link: _c.channelForCard(card.id),
        ),
      ),
    );
    return DragTarget<PipePayload>(
      onWillAcceptWithDetails: (DragTargetDetails<PipePayload> d) =>
          d.data.sourceCardId != card.id &&
          (_linkableTypes[descriptor.id]?.contains(d.data.type) ?? false),
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
  List<({Offset a, Offset b})> _linkSegments(List<CanvasCard> cards) {
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
        segments.add((a: _anchor(members[i]), b: _anchor(members[i + 1])));
      }
    }
    return segments;
  }

  Offset _anchor(CanvasCard card) =>
      Offset(card.x + _pan.dx + card.width / 2, card.y + _pan.dy + 18);

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
  _DotGridPainter({required this.color, required this.offset});

  final Color color;
  final Offset offset;

  static const double _step = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double startX = offset.dx % _step;
    final double startY = offset.dy % _step;
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
