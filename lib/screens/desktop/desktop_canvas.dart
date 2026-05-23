import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../state/canvas_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../widgets/desktop/command_palette.dart';
import '../../widgets/desktop/desktop_icon_grid.dart';
import '../../widgets/desktop/pipe.dart';
import '../../widgets/desktop/tool_card_frame.dart';
import '../../widgets/tool_bodies/seed_source.dart';

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

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
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
    final List<CanvasCard> cards = _c.cards;
    return ClipRect(
      child: ColoredBox(
        key: _surfaceKey,
        color: const Color(0x00000000),
        child: Stack(
          children: <Widget>[
            // Background: drag on empty space to pan; dot grid scrolls with it.
            // A DragTarget overlays the pan gesture so a cell dropped on empty
            // space opens a new seeded card. DragTarget doesn't consume pans, so
            // the empty-space pan stays live.
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
                      child: CustomPaint(
                        painter: _DotGridPainter(color: c.border, offset: _pan),
                      ),
                    ),
              ),
            ),
            // Icon grid: fixed (no pan offset), above dot-grid, below cards.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topLeft,
                child: DesktopIconGrid(
                  onOpen: (UtilityDescriptor u) => _c.openTool(u),
                ),
              ),
            ),
            // Gold tether drawn behind the cards for each Link group.
            if (_c.hasLinks)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LinkLinePainter(
                      segments: _linkSegments(cards),
                      color: c.warning,
                    ),
                  ),
                ),
              ),
            for (int i = 0; i < cards.length; i++)
              Positioned(
                // Key the Positioned itself (not just the inner SizedBox) so a
                // card's State survives sibling inserts/removes — the gold-line
                // painter shifts child indices, and closing a middle card would
                // otherwise rebind the wrong element.
                key: ValueKey<int>(cards[i].id),
                left: cards[i].x + _pan.dx,
                top: cards[i].y + _pan.dy,
                child: SizedBox(
                  width: cards[i].width,
                  child: _cardFrame(cards[i], slot: i + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Empty-canvas drop: opens the best-matching tool for the dropped value at
  /// the drop point. The global offset is mapped to canvas-local coordinates
  /// (drop − surfaceTopLeft − pan) so the new card lands under the pointer.
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

  Widget _cardFrame(CanvasCard card, {required int slot}) {
    final SeedSource src = card.seed != null
        ? SeedSource.paste
        : SeedSource.none;
    final ({String partnerId, ContentType type})? partner =
        _linkPartners[card.descriptor.id];
    final bool linked = _c.groupForCard(card.id) != null;
    final ToolCardFrame frame = ToolCardFrame(
      descriptor: card.descriptor,
      slot: slot <= 9 ? slot : null,
      focused: _c.focusedId == card.id,
      onFocus: () => _c.focus(card.id),
      onClose: () => _c.close(card.id),
      onDuplicate: () => _c.duplicate(card.id),
      onMoveDelta: (Offset d) =>
          _c.moveTo(card.id, card.x + d.dx, card.y + d.dy),
      onMoveEnd: _c.commit,
      onResizeDelta: (double dx) => _c.resize(card.id, card.width + dx),
      onResizeEnd: _c.commit,
      linked: linked,
      // A linked card always offers Unlink — even one linked by drop-to-link
      // with no fixed [partner]. An unlinked card with a partner offers Open.
      // An unlinked card with no partner has no toggle.
      linkTooltip: linked
          ? 'Unlink'
          : partner == null
          ? null
          : 'Open linked ${UtilityCatalog.byId(partner.partnerId).name}',
      onLink: (linked || partner != null)
          ? () => _toggleLink(card, partner)
          : null,
      // PipeScope tells this card's output cells their source id and that pipe
      // mode is active; absent on mobile/Home so cells stay inert there.
      child: PipeScope(
        cardId: card.id,
        child: card.descriptor.builder(
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
    // Drop a cell onto this card → live link the two (reuses the proven engine).
    return DragTarget<PipePayload>(
      onWillAcceptWithDetails: (DragTargetDetails<PipePayload> d) =>
          d.data.sourceCardId != card.id &&
          (_linkableTypes[card.descriptor.id]?.contains(d.data.type) ?? false),
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

/// Draws the gold tether between linked cards (see docs/adr/0001).
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
      ..strokeCap = StrokeCap.round;
    for (final ({Offset a, Offset b}) s in segments) {
      canvas.drawLine(s.a, s.b, paint);
    }
  }

  @override
  bool shouldRepaint(_LinkLinePainter old) =>
      old.color != color || !listEquals(old.segments, segments);
}
