import 'package:flutter/cupertino.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class ContextMenuItem {
  const ContextMenuItem({
    required this.label,
    required this.action,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback action;
  final IconData? icon;
  final bool destructive;
}

/// Spawns a custom native-feeling glassmorphic context menu at the exact click position.
void showDesktopContextMenu(
  BuildContext context,
  Offset position,
  List<ContextMenuItem> items,
) {
  final OverlayState overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ContextMenuOverlay(
      position: position,
      items: items,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
  });

  final Offset position;
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Stack(
      children: <Widget>[
        // Dismiss tap detector covering full viewport
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          onSecondaryTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(MqRadius.sm),
              border: Border.all(color: c.border, width: 0.5),
              boxShadow: c.shadow,
            ),
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.xs),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final ContextMenuItem item in items)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        onDismiss();
                        item.action();
                      },
                      child: _MenuItemWidget(item: item),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItemWidget extends StatefulWidget {
  const _MenuItemWidget({required this.item});
  final ContextMenuItem item;

  @override
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color textColor = widget.item.destructive
        ? c.danger
        : _hovered
        ? c.accent
        : c.textPri;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? c.accentBg : const Color(0x00000000),
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.item.icon != null) ...<Widget>[
              Icon(widget.item.icon, size: 14, color: textColor),
              const SizedBox(width: MqSpacing.sm),
            ],
            Expanded(
              child: Text(
                widget.item.label,
                style: MqTextStyles.caption1.copyWith(
                  color: textColor,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
