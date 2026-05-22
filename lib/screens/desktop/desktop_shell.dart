import 'package:flutter/cupertino.dart';

import '../../state/canvas_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
import 'desktop_canvas.dart';
import 'desktop_sidebar.dart';

/// Web desktop layout: a fixed left [DesktopSidebar] plus a content pane. The
/// Home nav shows a [DesktopCanvas] — a multi-card surface where tools open as
/// draggable cards; History and Settings show their own screens. The
/// [CanvasController] lives here so open cards survive nav switches.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  /// Identifies the bordered, height-capped shell window (for tests/geometry).
  static const Key windowKey = ValueKey<String>('desktop-shell-window');

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _navIndex = 0;
  final CanvasController _canvas = CanvasController();

  @override
  void dispose() {
    _canvas.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    const BorderRadius windowRadius = BorderRadius.all(
      Radius.circular(MqRadius.lg),
    );
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      // Bind the shell to a centered, bordered window: cap its width and height
      // and lift it off the page with a hairline + shadow, so tall/ultrawide
      // viewports read as intentional margin instead of empty stretch.
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            // minHeight == maxHeight pins the window to a tight height (capped
            // to the viewport) so the embedded scaffolds get a bounded height;
            // Center then drops the slack as symmetric top/bottom margin.
            constraints: const BoxConstraints(
              maxWidth: MqLayout.desktopShellMaxWidth,
              minHeight: MqLayout.desktopShellMaxHeight,
              maxHeight: MqLayout.desktopShellMaxHeight,
            ),
            child: DecoratedBox(
              // Shadow sits on the outer box so the clip below doesn't crop it.
              decoration: BoxDecoration(
                borderRadius: windowRadius,
                boxShadow: c.shadowLg,
              ),
              child: Container(
                key: DesktopShell.windowKey,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: windowRadius,
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DesktopSidebar(selectedIndex: _navIndex, onSelect: _select),
                    Expanded(child: _pane()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pane() {
    return switch (_navIndex) {
      1 => _capped(
        maxWidth: MqLayout.readableMaxWidth,
        child: const HistoryScreen(),
      ),
      2 => _capped(
        maxWidth: MqLayout.readableMaxWidth,
        child: const SettingsScreen(),
      ),
      _ => _capped(
        maxWidth: MqLayout.desktopContentMaxWidth,
        child: DesktopCanvas(controller: _canvas),
      ),
    };
  }

  /// Centers [child] and caps its width, while keeping it full-height so the
  /// embedded scaffolds (which expect a bounded height) lay out correctly.
  Widget _capped({required double maxWidth, required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minHeight: double.infinity,
        ),
        child: child,
      ),
    );
  }
}
