import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../state/canvas_controller.dart';
import '../../state/density_controller.dart';
import '../../state/view_mode_controller.dart';
import '../../theme/mq_density.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'command_palette.dart';
import 'layouts_sheet.dart';

/// Mac-style menubar pinned to the top of the desktop shell. Full-width, fixed
/// height ([MqLayout.menubarHeight]). Left: brand glyph + menu titles. Right:
/// live clock (updates each minute).
class DesktopMenubar extends StatefulWidget {
  const DesktopMenubar({
    super.key,
    required this.controller,
    required this.onPasteOpen,
    required this.onOpenSettings,
    required this.onOpenHistory,
  });

  final CanvasController controller;
  final VoidCallback onPasteOpen;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;

  @override
  State<DesktopMenubar> createState() => _DesktopMenubarState();
}

class _DesktopMenubarState extends State<DesktopMenubar> {
  Timer? _clockTimer;
  String _time = '';

  CanvasController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTime(),
    );
    _c.addListener(_onCanvasChange);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _c.removeListener(_onCanvasChange);
    super.dispose();
  }

  void _onCanvasChange() {
    if (mounted) setState(() {});
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String h = now.hour.toString().padLeft(2, '0');
    final String m = now.minute.toString().padLeft(2, '0');
    if (mounted) {
      setState(() => _time = '$h:$m');
    } else {
      _time = '$h:$m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      height: MqLayout.menubarHeight,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.md),
      child: Row(
        children: <Widget>[
          _MenuButton(
            label: '⏻ Masquerade',
            bold: true,
            items: <_MenuItem>[
              _MenuItem('About Masquerade', _showAbout),
              _MenuItem('Settings…', widget.onOpenSettings),
              _MenuItem('History…', widget.onOpenHistory),
              _MenuItem('Mobile view', _switchToMobile),
            ],
          ),
          _MenuButton(
            label: 'File',
            items: <_MenuItem>[
              _MenuItem('New tool…  ⌘K', _openPalette),
              _MenuItem('Save Layout…', _openLayouts),
              _MenuItem('Open Layout…', _openLayouts),
              _MenuItem('Close Window  ⌘W', _closeWindow),
              _MenuItem('Close All', _closeAll),
            ],
          ),
          _MenuButton(
            label: 'Edit',
            items: <_MenuItem>[
              _MenuItem('Paste & Detect  ⌘V', widget.onPasteOpen),
              _MenuItem('Duplicate Window  ⌥D', _duplicate),
            ],
          ),
          _MenuButton(
            label: 'View',
            items: <_MenuItem>[
              _MenuItem(_densityLabel(context), _toggleDensity),
            ],
          ),
          _MenuButton(
            label: 'Window',
            items: <_MenuItem>[
              for (final CanvasCard card in _c.cards)
                _MenuItem(card.descriptor.name, () => _c.focus(card.id)),
              if (_c.cards.isNotEmpty) _MenuItem('Close All', _closeAll),
            ],
          ),
          const Spacer(),
          Text(_time, style: MqTextStyles.caption2.copyWith(color: c.textSec)),
        ],
      ),
    );
  }

  String _densityLabel(BuildContext context) {
    final DensityController dc = DensityScope.of(context);
    return dc.mode == MqDensityMode.compact
        ? 'Density: Comfortable'
        : 'Density: Compact';
  }

  void _toggleDensity() {
    final DensityController dc = DensityScope.of(context);
    dc.setMode(
      dc.mode == MqDensityMode.compact
          ? MqDensityMode.comfortable
          : MqDensityMode.compact,
    );
  }

  void _switchToMobile() {
    ViewModeScope.of(context).setMode(MqViewMode.mobile);
  }

  Future<void> _showAbout() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Masquerade'),
        content: Text('Version ${info.version}'),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPalette() async {
    final PaletteResult? r = await showCommandPalette(context);
    if (r != null && mounted) _c.openTool(r.tool, seed: r.seed);
  }

  void _openLayouts() => showLayoutsSheet(context, _c);

  void _closeWindow() {
    final int? id = _c.focusedId;
    if (id != null) _c.close(id);
  }

  void _closeAll() => _c.closeAll();

  void _duplicate() {
    final int? id = _c.focusedId;
    if (id != null) _c.duplicate(id);
  }
}

/// A single menubar title that opens a dropdown on tap.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.items,
    this.bold = false,
  });

  final String label;
  final List<_MenuItem> items;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
      minimumSize: const Size(0, MqLayout.menubarHeight),
      onPressed: items.isEmpty ? null : () => _showMenu(context),
      child: Text(
        label,
        style: MqTextStyles.caption2.copyWith(
          color: c.textPri,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset pos = box.localToGlobal(Offset(0, box.size.height));
    final OverlayState overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MenuOverlay(
        position: pos,
        items: items,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

/// Overlay dropdown for a menu.
class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
  });

  final Offset position;
  final List<_MenuItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Stack(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Container(
            constraints: const BoxConstraints(minWidth: 180),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MqRadius.xs),
              border: Border.all(color: c.border, width: 0.5),
              boxShadow: c.shadow,
            ),
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.xs),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final _MenuItem item in items)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        onDismiss();
                        item.action();
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MqSpacing.md,
                            vertical: MqSpacing.xs + 2,
                          ),
                          child: Text(
                            item.label,
                            style: MqTextStyles.caption1.copyWith(
                              color: c.textPri,
                            ),
                          ),
                        ),
                      ),
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

class _MenuItem {
  const _MenuItem(this.label, this.action);
  final String label;
  final VoidCallback action;
}
