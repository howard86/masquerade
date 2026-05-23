import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/canvas_controller.dart';
import '../../state/window_content.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../widgets/desktop/desktop_dock.dart';
import '../../widgets/desktop/desktop_menubar.dart';
import '../../widgets/desktop/desktop_wallpaper.dart';
import 'desktop_canvas.dart';

/// Full-bleed desktop shell: a Mac-style [DesktopMenubar] pinned at the top,
/// with the [DesktopCanvas] filling the remaining viewport over a themed
/// [DesktopWallpaper]. Replaces the former centered/bordered/height-capped
/// window + sidebar layout.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key, this.isWebOverride});

  /// See `MyApp.isWebOverride`. Passed through to Settings dialog.
  final bool? isWebOverride;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final CanvasController _canvas = CanvasController();

  @override
  void initState() {
    super.initState();
    _attachCanvasPrefs();
  }

  Future<void> _attachCanvasPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _canvas.attachPrefs(prefs);
  }

  @override
  void dispose() {
    _canvas.dispose();
    super.dispose();
  }

  /// Shared paste-detect logic used by both the canvas key handler and the
  /// menubar Edit → Paste & Detect item.
  Future<void> _pasteOpen() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final List<UtilityDescriptor> matches = UtilityCatalog.detectAll(text);
    if (matches.isEmpty) return;
    _canvas.openTool(matches.first, seed: text);
  }

  void _openSettings() {
    _canvas.openSystem(SystemApp.settings);
  }

  void _openHistory() {
    _canvas.openSystem(SystemApp.history);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: Column(
        children: <Widget>[
          DesktopMenubar(
            controller: _canvas,
            onPasteOpen: _pasteOpen,
            onOpenSettings: _openSettings,
            onOpenHistory: _openHistory,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: DesktopWallpaper()),
                Positioned.fill(child: DesktopCanvas(controller: _canvas)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MqSpacing.md,
                  child: Center(
                    child: ListenableBuilder(
                      listenable: _canvas,
                      builder: (BuildContext context, Widget? _) =>
                          DesktopDock(controller: _canvas),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
