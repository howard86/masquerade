import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../history_screen.dart';
import '../home_screen.dart';
import '../settings_screen.dart';
import 'desktop_sidebar.dart';
import 'desktop_tool_view.dart';

/// Web desktop layout: a fixed left [DesktopSidebar] plus a content pane that
/// shows the selected nav screen (Home / History / Settings) or, when a tool is
/// open, a [DesktopToolView]. Tools open in-pane (no route push) so the sidebar
/// stays put; cross-tool "Open in X" pushes onto the in-pane tool stack.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  /// Identifies the bordered, height-capped shell window (for tests/geometry).
  static const Key windowKey = ValueKey<String>('desktop-shell-window');

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _navIndex = 0;
  final List<_PaneTool> _tools = <_PaneTool>[];

  void _select(int index) {
    setState(() {
      _navIndex = index;
      _tools.clear();
    });
  }

  void _openTool(UtilityDescriptor descriptor, String seed) {
    setState(() {
      _tools.add(_PaneTool(descriptor, seed.isEmpty ? null : seed));
    });
  }

  void _back() {
    setState(() {
      if (_tools.isNotEmpty) _tools.removeLast();
    });
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
    if (_tools.isNotEmpty) {
      final _PaneTool top = _tools.last;
      return _capped(
        maxWidth: MqLayout.readableMaxWidth,
        child: DesktopToolView(
          key: ValueKey<String>('tool-${_tools.length}-${top.descriptor.id}'),
          descriptor: top.descriptor,
          seed: top.seed,
          onBack: _back,
          onSwitchTool: _openTool,
        ),
      );
    }
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
        child: HomeScreen(onOpenTool: _openTool),
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

class _PaneTool {
  const _PaneTool(this.descriptor, this.seed);
  final UtilityDescriptor descriptor;
  final String? seed;
}
