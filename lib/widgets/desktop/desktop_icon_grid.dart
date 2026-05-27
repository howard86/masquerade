import 'package:flutter/cupertino.dart';

import '../../state/window_content.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';

/// Always-present launcher icon grid. Aligned vertically on the right edge of
/// the desktop viewport (macOS style), keeping the center workspace spacious.
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
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.md,
        MqSpacing.lg,
        MqSpacing.md,
        MqSpacing.xl * 2 + 16, // clear the menubar top and dock bottom
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final UtilityDescriptor d
                    in UtilityCatalog.all) ...<Widget>[
                  _DesktopIconTile(descriptor: d, onOpen: () => onOpen(d)),
                  const SizedBox(height: MqSpacing.sm),
                ],
                for (final SystemApp app in SystemApp.values) ...<Widget>[
                  _SystemIconTile(app: app, onOpen: () => onOpenSystem(app)),
                  const SizedBox(height: MqSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single system-app icon tile (History / Settings) with visual spring bounce.
class _SystemIconTile extends StatefulWidget {
  const _SystemIconTile({required this.app, required this.onOpen});

  final SystemApp app;
  final VoidCallback onOpen;

  @override
  State<_SystemIconTile> createState() => _SystemIconTileState();
}

class _SystemIconTileState extends State<_SystemIconTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _bounceController.animateTo(0.88, curve: Curves.easeOut);
    await _bounceController.animateTo(1.0, curve: Curves.elasticOut);
    widget.onOpen();
  }

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
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _bounceController,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _hovered
                  ? c.surface.withValues(alpha: 0.15)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MqRadius.md),
              border: Border.all(
                color: _hovered
                    ? c.border.withValues(alpha: 0.25)
                    : const Color(0x00000000),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(sw.icon, size: 24, color: sw.tint),
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
      ),
    );
  }
}

/// A single 78×78 utility icon tile: icon + label with interactive hover scale and spring click.
class _DesktopIconTile extends StatefulWidget {
  const _DesktopIconTile({required this.descriptor, required this.onOpen});

  final UtilityDescriptor descriptor;
  final VoidCallback onOpen;

  @override
  State<_DesktopIconTile> createState() => _DesktopIconTileState();
}

class _DesktopIconTileState extends State<_DesktopIconTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _bounceController.animateTo(0.88, curve: Curves.easeOut);
    await _bounceController.animateTo(1.0, curve: Curves.elasticOut);
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _bounceController,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _hovered
                  ? c.surface.withValues(alpha: 0.15)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MqRadius.md),
              border: Border.all(
                color: _hovered
                    ? c.border.withValues(alpha: 0.25)
                    : const Color(0x00000000),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  widget.descriptor.icon,
                  size: 24,
                  color: widget.descriptor.tint,
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
      ),
    );
  }
}
