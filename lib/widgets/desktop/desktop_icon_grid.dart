import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/window_content.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
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
  static const double _tileStride = 78 + MqSpacing.sm;

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
          final List<Widget> tiles = <Widget>[
            for (final UtilityDescriptor d in UtilityCatalog.all)
              _LauncherTile(
                icon: d.icon,
                tint: d.tint,
                label: d.name,
                onOpen: () => onOpen(d),
              ),
            for (final SystemApp app in SystemApp.values)
              _LauncherTile(
                icon: SystemWindow(app).icon,
                tint: SystemWindow(app).tint,
                label: SystemWindow(app).title,
                onOpen: () => onOpenSystem(app),
              ),
          ];
          final int availableRows = (constraints.maxHeight / _tileStride)
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

/// A single 78×78 launcher tile: icon + label with hover scale, spring click,
/// and keyboard operability. Focusable via Tab; Enter/Space activate it through
/// the same [onOpen] path as a click, and it is announced as a button labelled
/// with the tool name to screen readers.
class _LauncherTile extends StatefulWidget {
  const _LauncherTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onOpen,
  });

  final IconData icon;
  final Color tint;
  final String label;
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
    final c = context.mq.colors;
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: highlighted
                      ? c.surface.withValues(alpha: 0.15)
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(MqRadius.md),
                  border: Border.all(
                    color: _focused
                        ? c.accent
                        : _hovered
                        ? c.border.withValues(alpha: 0.25)
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MqTextStyles.caption2.copyWith(
                        color: c.textPri,
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
    );
  }
}
