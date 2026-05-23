import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/canvas_controller.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../widgets/desktop/desktop_menubar.dart';
import '../../widgets/desktop/desktop_wallpaper.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
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
    Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _DialogWrapper(
          title: 'Settings',
          child: SettingsScreen(isWebOverride: widget.isWebOverride),
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            const _DialogWrapper(title: 'History', child: HistoryScreen()),
      ),
    );
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin wrapper for full-screen dialog routes (Settings, History). Provides a
/// [CupertinoNavigationBar] with a Done button that pops the route.
class _DialogWrapper extends StatelessWidget {
  const _DialogWrapper({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: child,
    );
  }
}
