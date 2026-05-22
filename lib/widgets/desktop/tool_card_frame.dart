import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../mq/mq_icons.dart';

/// Card chrome for the desktop canvas: a draggable title bar (grip · name ·
/// slot tag · duplicate · close) over the embedded tool [child], plus a
/// right-edge resize handle. The body inside is the unmodified
/// `descriptor.builder(...)` output — the frame knows nothing about which tool
/// it wraps beyond the descriptor's name and tint.
class ToolCardFrame extends StatelessWidget {
  const ToolCardFrame({
    super.key,
    required this.descriptor,
    required this.slot,
    required this.focused,
    required this.onFocus,
    required this.onClose,
    required this.onDuplicate,
    required this.onMoveDelta,
    required this.onResizeDelta,
    required this.child,
  });

  final UtilityDescriptor descriptor;

  /// 1-based slot for the ⌥N tag, or null when beyond slot 9.
  final int? slot;
  final bool focused;
  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onDuplicate;

  /// Called with the drag delta while the title bar is dragged.
  final ValueChanged<Offset> onMoveDelta;

  /// Called with the horizontal drag delta while the resize handle is dragged.
  final ValueChanged<double> onResizeDelta;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MqRadius.md),
            border: Border.all(
              color: focused ? c.accent : c.border,
              width: focused ? 1 : 0.5,
            ),
            boxShadow: c.shadowLg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MqRadius.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  descriptor: descriptor,
                  slot: slot,
                  onFocus: onFocus,
                  onClose: onClose,
                  onDuplicate: onDuplicate,
                  onMoveDelta: onMoveDelta,
                ),
                Padding(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  child: child,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: -2,
          width: 10,
          child: _ResizeHandle(onResizeDelta: onResizeDelta),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.descriptor,
    required this.slot,
    required this.onFocus,
    required this.onClose,
    required this.onDuplicate,
    required this.onMoveDelta,
  });

  final UtilityDescriptor descriptor;
  final int? slot;
  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onDuplicate;
  final ValueChanged<Offset> onMoveDelta;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFocus,
      onPanStart: (_) => onFocus(),
      onPanUpdate: (DragUpdateDetails d) => onMoveDelta(d.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              _Grip(color: c.textTer),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(
                  descriptor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MqTextStyles.sectionLabel.copyWith(color: c.textPri),
                ),
              ),
              if (slot != null) ...<Widget>[
                Text(
                  '⌥$slot',
                  style: MqTextStyles.monoSm.copyWith(color: c.textTer),
                ),
                const SizedBox(width: MqSpacing.sm),
              ],
              _IconButton(
                icon: MqIcons.copy,
                tooltip: 'Duplicate (⌥D)',
                onTap: onDuplicate,
              ),
              _IconButton(
                icon: MqIcons.xmark,
                tooltip: 'Close (Esc)',
                onTap: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 2×3 dot grid that reads as a drag affordance.
class _Grip extends StatelessWidget {
  const _Grip({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 2.5,
      height: 2.5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    Widget col() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot(),
        const SizedBox(height: 2),
        dot(),
        const SizedBox(height: 2),
        dot(),
      ],
    );
    return Opacity(
      opacity: 0.7,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[col(), const SizedBox(width: 2), col()],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
          child: Icon(icon, size: 15, color: c.textTer, semanticLabel: tooltip),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onResizeDelta});
  final ValueChanged<double> onResizeDelta;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails d) =>
            onResizeDelta(d.delta.dx),
        child: const SizedBox.expand(),
      ),
    );
  }
}
