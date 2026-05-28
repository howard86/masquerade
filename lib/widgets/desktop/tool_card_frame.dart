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
    required this.onResizeEdge,
    required this.onResizeEnd,
    required this.child,
    this.onDuplicate,
    this.maximized = false,
    this.height,
    this.linked = false,
    this.linkTooltip,
    this.onLink,
    this.scrollBody = true,
    this.onSecondaryTapDown,
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

  /// Called with details when any of the 8 resize handles are dragged.
  final void Function(
    double dx,
    double dy, {
    required bool left,
    required bool right,
    required bool top,
    required bool bottom,
    required double measuredHeight,
  }) onResizeEdge;

  /// Called once the resize drag settles (persist hook).
  final VoidCallback onResizeEnd;

  /// Whether the frame wraps the child in a SingleChildScrollView when height
  /// is bounded. Set to false for system windows whose body scrolls itself.
  final bool scrollBody;

  final Widget child;
  final GestureTapDownCallback? onSecondaryTapDown;

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
    final Widget focusableBody = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => onFocus(),
      child: body,
    );
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
                  onSecondaryTapDown: onSecondaryTapDown,
                ),
                if (height != null) Expanded(child: focusableBody) else focusableBody,
              ],
            ),
          ),
        ),
        if (!maximized) ...<Widget>[
          // Top edge
          Positioned(
            top: -4,
            left: 8,
            right: 8,
            height: 8,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpDown,
              left: false,
              right: false,
              top: true,
              bottom: false,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Bottom edge
          Positioned(
            bottom: -4,
            left: 8,
            right: 8,
            height: 8,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpDown,
              left: false,
              right: false,
              top: false,
              bottom: true,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Left edge
          Positioned(
            left: -4,
            top: 8,
            bottom: 8,
            width: 8,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeLeftRight,
              left: true,
              right: false,
              top: false,
              bottom: false,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Right edge
          Positioned(
            right: -4,
            top: 8,
            bottom: 8,
            width: 8,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeLeftRight,
              left: false,
              right: true,
              top: false,
              bottom: false,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Top-Left corner
          Positioned(
            left: -6,
            top: -6,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              left: true,
              right: false,
              top: true,
              bottom: false,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Top-Right corner
          Positioned(
            right: -6,
            top: -6,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              left: false,
              right: true,
              top: true,
              bottom: false,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Bottom-Left corner
          Positioned(
            left: -6,
            bottom: -6,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              left: true,
              right: false,
              top: false,
              bottom: true,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
          // Bottom-Right corner
          Positioned(
            right: -6,
            bottom: -6,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              left: false,
              right: true,
              top: false,
              bottom: true,
              onResizeDelta: (dx, dy, left, right, top, bottom) {
                final double measuredHeight = context.size?.height ?? 400.0;
                onResizeEdge(dx, dy, left: left, right: right, top: top, bottom: bottom, measuredHeight: measuredHeight);
              },
              onResizeEnd: onResizeEnd,
            ),
          ),
        ],
      ],
    );
  }
}

/// Approximate header height for body height calculation.
const double _kHeaderHeight = 36;

class _Header extends StatefulWidget {
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
    this.onSecondaryTapDown,
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
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onFocus,
      onPanStart: widget.maximized
          ? null
          : (_) {
              widget.onFocus();
              setState(() => _isDragging = true);
            },
      onPanUpdate: widget.maximized
          ? null
          : (DragUpdateDetails d) => widget.onMoveDelta(d.delta),
      onPanEnd: widget.maximized
          ? null
          : (_) {
              setState(() => _isDragging = false);
              widget.onMoveEnd();
            },
      onPanCancel: widget.maximized
          ? null
          : () {
              setState(() => _isDragging = false);
            },
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: MouseRegion(
        cursor: widget.maximized
            ? SystemMouseCursors.basic
            : (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.sm - 2,
          ),
          child: Row(
            children: <Widget>[
              // Traffic lights: close (red), minimize (yellow), maximize (green)
              _TrafficLight(
                color: c.danger,
                tooltip: 'Close (Esc)',
                onTap: widget.onClose,
                icon: CupertinoIcons.xmark,
              ),
              const SizedBox(width: MqSpacing.xs - 2),
              _TrafficLight(
                color: c.warning,
                tooltip: 'Minimize',
                onTap: widget.onMinimize,
                icon: CupertinoIcons.minus,
              ),
              const SizedBox(width: MqSpacing.xs - 2),
              _TrafficLight(
                color: c.success,
                tooltip: widget.maximized ? 'Restore' : 'Maximize',
                onTap: widget.onToggleMaximize,
                icon: CupertinoIcons.plus,
              ),
              const SizedBox(width: MqSpacing.sm - 2),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: widget.onToggleMaximize,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MqTextStyles.sectionLabel.copyWith(color: c.textPri),
                  ),
                ),
              ),
              if (widget.slot != null) ...<Widget>[
                Text(
                  '⌥${widget.slot}',
                  style: MqTextStyles.monoSm.copyWith(color: c.textTer),
                ),
                const SizedBox(width: MqSpacing.sm),
              ],
              if (widget.onLink != null)
                _IconButton(
                  icon: MqIcons.link,
                  tooltip: widget.linkTooltip ?? 'Link',
                  onTap: widget.onLink!,
                  color: widget.linked ? c.warning : null,
                ),
              if (widget.onDuplicate != null)
                _IconButton(
                  icon: MqIcons.copy,
                  tooltip: 'Duplicate (⌥D)',
                  onTap: widget.onDuplicate!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single traffic-light dot button with hover states.
class _TrafficLight extends StatefulWidget {
  const _TrafficLight({
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;

  @override
  State<_TrafficLight> createState() => _TrafficLightState();
}

class _TrafficLightState extends State<_TrafficLight> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          label: widget.tooltip,
          button: true,
          child: Container(
            width: 16,
            height: 16,
            color: const Color(0x00000000), // Padded hit target
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Icon(
                      widget.icon,
                      size: 8,
                      color: const Color(0x90000000), // elegant dark semi-transparent glyph
                    ),
                  ),
                ),
              ),
            ),
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

/// Generic resize handle that reports granular drag updates.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.cursor,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.onResizeDelta,
    required this.onResizeEnd,
  });

  final MouseCursor cursor;
  final bool left;
  final bool right;
  final bool top;
  final bool bottom;
  final void Function(double dx, double dy, bool left, bool right, bool top, bool bottom) onResizeDelta;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (DragUpdateDetails d) {
          final double dx = (left || right) ? d.delta.dx : 0.0;
          final double dy = (top || bottom) ? d.delta.dy : 0.0;
          onResizeDelta(dx, dy, left, right, top, bottom);
        },
        onPanEnd: (_) => onResizeEnd(),
        onPanCancel: onResizeEnd,
        child: const SizedBox.expand(),
      ),
    );
  }
}
