import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/window_content.dart';
import '../../state/wallpaper_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';

/// Arrow keys → spatial focus moves across the launcher tiles. Bound on the
/// grid itself (an explicit, intended contract — not an accidental inheritance
/// of [WidgetsApp.defaultShortcuts]) so its 2D traversal holds regardless of
/// the host shell's key handling or platform/web shortcut differences. The
/// app-wide [DirectionalFocusAction] resolves the geometrically-adjacent tile
/// from the focus tree, so no manual geometry math is needed here.
const Map<ShortcutActivator, Intent> _arrowTraversal =
    <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
        TraversalDirection.up,
      ),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
        TraversalDirection.down,
      ),
      SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
        TraversalDirection.left,
      ),
      SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
        TraversalDirection.right,
      ),
    };

/// Always-present launcher icon grid. Aligned vertically on the right edge of
/// the desktop viewport (macOS style), flowing into columns from right to left
/// so every launcher remains visible at the native Mac window's minimum size.
class DesktopIconGrid extends StatelessWidget {
  const DesktopIconGrid({
    super.key,
    required this.onOpen,
    required this.onOpenSystem,
  });

  final void Function(UtilityDescriptor descriptor) onOpen;
  final void Function(SystemApp app) onOpenSystem;

  static const double _columnWidth = 84;
  static const double _tileWidth = 78;

  static double _tileHeight(BuildContext context) {
    final TextStyle labelStyle = MqTextStyles.caption2;
    final double fontSize = labelStyle.fontSize ?? 11;
    final double scaledLineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) *
        (labelStyle.height ?? 1);
    // Reserve two label lines, the icon, their gap, the largest focus border,
    // and one pixel of rounding slack. Keep the original footprint at ordinary
    // text sizes and grow it with dynamic type so labels and hit targets never
    // overlap the next row.
    final double contentHeight = 24 + MqSpacing.xs + 2 * scaledLineHeight + 4;
    return contentHeight > 78 ? contentHeight : 78;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.md,
        MqSpacing.lg,
        MqSpacing.md,
        MqSpacing.xl * 2 + 16, // clear the menubar top and dock bottom
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tileHeight = _tileHeight(context);
          final double tileStride = tileHeight + MqSpacing.sm;
          final List<UtilityDescriptor> tools = UtilityCatalog.all.toList()
            ..sort(
              (UtilityDescriptor a, UtilityDescriptor b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          final List<Widget> tiles = <Widget>[
            for (final UtilityDescriptor d in tools)
              _LauncherTile(
                icon: d.icon,
                tint: d.tint,
                label: d.name,
                height: tileHeight,
                onOpen: () => onOpen(d),
              ),
            for (final SystemApp app in SystemApp.values)
              _LauncherTile(
                icon: SystemWindow(app).icon,
                tint: SystemWindow(app).tint,
                label: SystemWindow(app).title,
                height: tileHeight,
                onOpen: () => onOpenSystem(app),
              ),
          ];
          final int availableRows = (constraints.maxHeight / tileStride)
              .floor();
          final int rowCount = availableRows.clamp(1, tiles.length);
          final int columnCount = (tiles.length + rowCount - 1) ~/ rowCount;

          return Align(
            alignment: Alignment.topRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              // Keyboard users Tab/Shift-Tab through the launcher in visual
              // order; arrow keys move to the spatially-adjacent tile.
              child: Shortcuts(
                shortcuts: _arrowTraversal,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int column = 0; column < columnCount; column++)
                        SizedBox(
                          width: _columnWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (
                                int index = column * rowCount;
                                index <
                                    ((column + 1) * rowCount).clamp(
                                      0,
                                      tiles.length,
                                    );
                                index++
                              ) ...<Widget>[
                                FocusTraversalOrder(
                                  order: NumericFocusOrder(index.toDouble()),
                                  child: tiles[index],
                                ),
                                const SizedBox(height: MqSpacing.sm),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A launcher tile: icon + label with hover scale, spring click, and keyboard
/// operability. Focusable via Tab; Enter/Space activate it through the same
/// [onOpen] path as a click, and it is announced as a button labelled with the
/// tool name to screen readers.
class _LauncherTile extends StatefulWidget {
  const _LauncherTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.height,
    required this.onOpen,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final double height;
  final VoidCallback onOpen;

  @override
  State<_LauncherTile> createState() => _LauncherTileState();
}

class _LauncherTileState extends State<_LauncherTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _focused = false;
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
    final bool darkWallpaper = WallpaperScope.of(context).type.isDark;
    final Color labelColor = darkWallpaper
        ? const Color(0xFFF5F1ED)
        : const Color(0xFF211D19);
    final bool highlighted = _hovered || _focused;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: _handleTap,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (bool v) => setState(() => _hovered = v),
          onShowFocusHighlight: (bool v) => setState(() => _focused = v),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _handleTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: ScaleTransition(
              scale: _bounceController,
              // The hover/focus highlight animates on its own layer so it
              // doesn't repaint the whole grid.
              child: RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: DesktopIconGrid._tileWidth,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? labelColor.withValues(alpha: 0.15)
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(MqRadius.md),
                    border: Border.all(
                      color: _focused
                          ? labelColor
                          : _hovered
                          ? labelColor.withValues(alpha: 0.25)
                          : const Color(0x00000000),
                      width: _focused ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(widget.icon, size: 24, color: widget.tint),
                      const SizedBox(height: MqSpacing.xs),
                      Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: MqTextStyles.caption2.copyWith(
                          color: labelColor,
                          shadows: darkWallpaper
                              ? <Shadow>[
                                  Shadow(
                                    color: const Color(
                                      0xFF000000,
                                    ).withValues(alpha: 0.65),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                          fontWeight: highlighted
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
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
