import 'package:flutter/cupertino.dart';

import '../../state/window_content.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';

/// Always-present auto-grid of tool icons on the desktop wallpaper. Each tile
/// is clickable (single-click opens); gaps between tiles are transparent to
/// pointer events so the canvas pan gesture still works.
class DesktopIconGrid extends StatelessWidget {
  const DesktopIconGrid({
    super.key,
    required this.onOpen,
    required this.onOpenSystem,
  });

  final void Function(UtilityDescriptor descriptor) onOpen;
  final void Function(SystemApp app) onOpenSystem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Wrap(
        spacing: MqSpacing.md,
        runSpacing: MqSpacing.lg,
        children: <Widget>[
          for (final UtilityDescriptor d in UtilityCatalog.all)
            _DesktopIconTile(descriptor: d, onOpen: () => onOpen(d)),
          for (final SystemApp app in SystemApp.values)
            _SystemIconTile(app: app, onOpen: () => onOpenSystem(app)),
        ],
      ),
    );
  }
}

/// A single system-app icon tile (History / Settings).
class _SystemIconTile extends StatefulWidget {
  const _SystemIconTile({required this.app, required this.onOpen});

  final SystemApp app;
  final VoidCallback onOpen;

  @override
  State<_SystemIconTile> createState() => _SystemIconTileState();
}

class _SystemIconTileState extends State<_SystemIconTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final SystemWindow sw = SystemWindow(widget.app);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: SizedBox(
          width: 84,
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hovered ? c.accentBg : null,
                  borderRadius: BorderRadius.circular(MqRadius.sm),
                ),
                child: Icon(sw.icon, size: 24, color: sw.tint),
              ),
              const SizedBox(height: MqSpacing.xs),
              Text(
                sw.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MqTextStyles.caption2.copyWith(
                  color: c.textPri,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single 84×84 icon tile: icon + label. Hit-tests only on itself (opaque),
/// so gaps pass through to the canvas pan layer below.
class _DesktopIconTile extends StatefulWidget {
  const _DesktopIconTile({required this.descriptor, required this.onOpen});

  final UtilityDescriptor descriptor;
  final VoidCallback onOpen;

  @override
  State<_DesktopIconTile> createState() => _DesktopIconTileState();
}

class _DesktopIconTileState extends State<_DesktopIconTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: SizedBox(
          width: 84,
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hovered ? c.accentBg : null,
                  borderRadius: BorderRadius.circular(MqRadius.sm),
                ),
                child: Icon(
                  widget.descriptor.icon,
                  size: 24,
                  color: widget.descriptor.tint,
                ),
              ),
              const SizedBox(height: MqSpacing.xs),
              Text(
                widget.descriptor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MqTextStyles.caption2.copyWith(
                  color: c.textPri,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
