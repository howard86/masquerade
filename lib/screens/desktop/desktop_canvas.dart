import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/canvas_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/desktop/command_palette.dart';
import '../../widgets/desktop/tool_card_frame.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/tool_bodies/seed_source.dart';
import '../home_screen.dart';

/// The desktop Home surface: a multi-card canvas. When no cards are open it
/// shows the familiar Home grid (so a tile-tap opens the first card); once a
/// card is open it switches to the pannable canvas with a compact top bar.
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
    final UtilityDescriptor? u = await showCommandPalette(context);
    if (u != null && mounted) _c.openTool(u);
  }

  Future<void> _pasteOpen() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(text);
    if (matches.isEmpty) return;
    _c.openTool(matches.first, seed: text);
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
      child: _c.isEmpty
          ? HomeScreen(
              onOpenTool: (UtilityDescriptor u, String seed) =>
                  _c.openTool(u, seed: seed),
            )
          : Column(
              children: <Widget>[
                _CanvasTopBar(
                  count: _c.length,
                  onPalette: _openViaPalette,
                  onPaste: _pasteOpen,
                  onCloseAll: _c.closeAll,
                ),
                Expanded(child: _surface(context)),
              ],
            ),
    );
  }

  Widget _surface(BuildContext context) {
    final c = context.mq.colors;
    final List<CanvasCard> cards = _c.cards;
    return ClipRect(
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: <Widget>[
            // Background: drag on empty space to pan; dot grid scrolls with it.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (DragUpdateDetails d) =>
                    setState(() => _pan += d.delta),
                child: CustomPaint(
                  painter: _DotGridPainter(color: c.border, offset: _pan),
                ),
              ),
            ),
            for (int i = 0; i < cards.length; i++)
              Positioned(
                left: cards[i].x + _pan.dx,
                top: cards[i].y + _pan.dy,
                child: SizedBox(
                  key: ValueKey<int>(cards[i].id),
                  width: cards[i].width,
                  child: _cardFrame(cards[i], slot: i + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardFrame(CanvasCard card, {required int slot}) {
    final SeedSource src = card.seed != null
        ? SeedSource.paste
        : SeedSource.none;
    return ToolCardFrame(
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
      child: card.descriptor.builder(
        context,
        initialInput: card.seed,
        seedSource: src,
        onSwitchTool: (UtilityDescriptor u, String input) =>
            _c.openTool(u, seed: input),
        actionBar: null,
      ),
    );
  }
}

class _CanvasTopBar extends StatelessWidget {
  const _CanvasTopBar({
    required this.count,
    required this.onPalette,
    required this.onPaste,
    required this.onCloseAll,
  });

  final int count;
  final VoidCallback onPalette;
  final VoidCallback onPaste;
  final VoidCallback onCloseAll;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.lg,
        vertical: MqSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Canvas',
            style: MqTextStyles.sectionLabel.copyWith(color: c.textTer),
          ),
          const SizedBox(width: MqSpacing.lg),
          _Pill(icon: MqIcons.search, label: '⌘K  Open tool', onTap: onPalette),
          const SizedBox(width: MqSpacing.sm),
          _Pill(icon: MqIcons.paste, label: 'Paste', onTap: onPaste),
          const Spacer(),
          Text(
            '$count ${count == 1 ? 'card' : 'cards'}',
            style: MqTextStyles.monoSm.copyWith(color: c.textTer),
          ),
          const SizedBox(width: MqSpacing.md),
          _Pill(icon: MqIcons.trash, label: 'Close all', onTap: onCloseAll),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: c.borderStrong, width: 0.5),
            borderRadius: BorderRadius.circular(MqRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 13, color: c.textSec),
              const SizedBox(width: MqSpacing.xs + 2),
              Text(
                label,
                style: MqTextStyles.caption1.copyWith(color: c.textSec),
              ),
            ],
          ),
        ),
      ),
    );
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
