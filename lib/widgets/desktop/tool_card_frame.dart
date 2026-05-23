import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../mq/mq_icons.dart';

/// Card chrome for the desktop canvas: a draggable title bar (traffic lights ·
/// name · slot tag · duplicate · link) over the embedded tool [child], plus a
/// right-edge resize handle. The body inside is the unmodified
/// `descriptor.builder(...)` output — the frame knows nothing about which tool
/// it wraps beyond the descriptor's name and tint.
class ToolCardFrame extends StatelessWidget {
  const ToolCardFrame({
    super.key,
    required this.title,
    required this.slot,
    required this.focused,
    required this.onFocus,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onMoveDelta,
    required this.onMoveEnd,
    required this.onResizeDelta,
    required this.onResizeEnd,
    required this.child,
    this.onDuplicate,
    this.maximized = false,
    this.height,
    this.linked = false,
    this.linkTooltip,
    this.onLink,
    this.scrollBody = true,
  });

  final String title;

  /// 1-based slot for the ⌥N tag, or null when beyond slot 9.
  final int? slot;
  final bool focused;
  final bool maximized;

  /// Explicit height; null = intrinsic (Column mainAxisSize.min).
  final double? height;

  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;

  /// When null, the duplicate button is hidden (system windows).
  final VoidCallback? onDuplicate;

  /// When [onLink] is non-null the header shows a link toggle. [linked] paints
  /// it gold (active) and [linkTooltip] is its accessibility label.
  final bool linked;
  final String? linkTooltip;
  final VoidCallback? onLink;

  /// Called with the drag delta while the title bar is dragged.
  final ValueChanged<Offset> onMoveDelta;

  /// Called once the title-bar drag settles (persist hook).
  final VoidCallback onMoveEnd;

  /// Called with the horizontal drag delta while the resize handle is dragged.
  final ValueChanged<double> onResizeDelta;

  /// Called once the resize drag settles (persist hook).
  final VoidCallback onResizeEnd;

  /// Whether the frame wraps the child in a SingleChildScrollView when height
  /// is bounded. Set to false for system windows whose body scrolls itself.
  final bool scrollBody;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Widget body;
    if (height != null) {
      if (scrollBody) {
        body = SizedBox(
          height: height! - _kHeaderHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MqSpacing.lg),
            child: child,
          ),
        );
      } else {
        body = SizedBox(height: height! - _kHeaderHeight, child: child);
      }
    } else {
      body = Padding(padding: const EdgeInsets.all(MqSpacing.lg), child: child);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          height: height,
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
              mainAxisSize: height != null
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  title: title,
                  slot: slot,
                  maximized: maximized,
                  onFocus: onFocus,
                  onClose: onClose,
                  onMinimize: onMinimize,
                  onToggleMaximize: onToggleMaximize,
                  onDuplicate: onDuplicate,
                  onMoveDelta: onMoveDelta,
                  onMoveEnd: onMoveEnd,
                  linked: linked,
                  linkTooltip: linkTooltip,
                  onLink: onLink,
                ),
                if (height != null) Expanded(child: body) else body,
              ],
            ),
          ),
        ),
        if (!maximized)
          Positioned(
            top: 0,
            bottom: 0,
            right: -2,
            width: 10,
            child: _ResizeHandle(
              onResizeDelta: onResizeDelta,
              onResizeEnd: onResizeEnd,
            ),
          ),
      ],
    );
  }
}

/// Approximate header height for body height calculation.
const double _kHeaderHeight = 36;

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.slot,
    required this.maximized,
    required this.onFocus,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onDuplicate,
    required this.onMoveDelta,
    required this.onMoveEnd,
    required this.linked,
    required this.linkTooltip,
    required this.onLink,
  });

  final String title;
  final int? slot;
  final bool maximized;
  final VoidCallback onFocus;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback? onDuplicate;
  final ValueChanged<Offset> onMoveDelta;
  final VoidCallback onMoveEnd;
  final bool linked;
  final String? linkTooltip;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFocus,
      onPanStart: maximized ? null : (_) => onFocus(),
      onPanUpdate: maximized
          ? null
          : (DragUpdateDetails d) => onMoveDelta(d.delta),
      onPanEnd: maximized ? null : (_) => onMoveEnd(),
      child: MouseRegion(
        cursor: maximized ? SystemMouseCursors.basic : SystemMouseCursors.grab,
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
              // Traffic lights: close (red), minimize (yellow), maximize (green)
              _TrafficLight(
                color: c.danger,
                tooltip: 'Close (Esc)',
                onTap: onClose,
              ),
              const SizedBox(width: MqSpacing.xs),
              _TrafficLight(
                color: c.warning,
                tooltip: 'Minimize',
                onTap: onMinimize,
              ),
              const SizedBox(width: MqSpacing.xs),
              _TrafficLight(
                color: c.success,
                tooltip: maximized ? 'Restore' : 'Maximize',
                onTap: onToggleMaximize,
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(
                  title,
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
              if (onLink != null)
                _IconButton(
                  icon: MqIcons.link,
                  tooltip: linkTooltip ?? 'Link',
                  onTap: onLink!,
                  color: linked ? c.warning : null,
                ),
              if (onDuplicate != null)
                _IconButton(
                  icon: MqIcons.copy,
                  tooltip: 'Duplicate (⌥D)',
                  onTap: onDuplicate!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single traffic-light dot button.
class _TrafficLight extends StatelessWidget {
  const _TrafficLight({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          label: tooltip,
          button: true,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Icon tint; defaults to the tertiary text color when null.
  final Color? color;

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
          child: Icon(
            icon,
            size: 15,
            color: color ?? c.textTer,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onResizeDelta, required this.onResizeEnd});
  final ValueChanged<double> onResizeDelta;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails d) =>
            onResizeDelta(d.delta.dx),
        onHorizontalDragEnd: (_) => onResizeEnd(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
