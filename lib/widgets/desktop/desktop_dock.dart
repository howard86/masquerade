import 'package:flutter/cupertino.dart';

import '../../state/canvas_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';

/// macOS-style dock pinned bottom-center. Shows one tile per open window;
/// minimized windows are dimmed. Hidden when no windows are open.
class DesktopDock extends StatelessWidget {
  const DesktopDock({super.key, required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final List<CanvasCard> cards = controller.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final c = context.mq.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.md,
        vertical: MqSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(MqRadius.lg),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: c.shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final CanvasCard card in cards)
            _DockTile(
              card: card,
              focused: controller.focusedId == card.id,
              onTap: () {
                if (card.minimized) {
                  controller.restoreWindow(card.id);
                } else {
                  controller.focus(card.id);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _DockTile extends StatefulWidget {
  const _DockTile({
    required this.card,
    required this.focused,
    required this.onTap,
  });

  final CanvasCard card;
  final bool focused;
  final VoidCallback onTap;

  @override
  State<_DockTile> createState() => _DockTileState();
}

class _DockTileState extends State<_DockTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final double opacity = widget.card.minimized ? 0.4 : 1.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.1 : 1.0,
          duration: MqMotion.fast,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hovered ? c.accentBg : c.surface2,
                      borderRadius: BorderRadius.circular(MqRadius.sm),
                    ),
                    child: Icon(
                      widget.card.content.icon,
                      size: 18,
                      color: widget.card.content.tint,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Running indicator dot.
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.focused ? c.accent : c.textTer,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
