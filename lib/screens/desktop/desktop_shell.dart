import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/artifact.dart';
import '../../state/canvas_controller.dart';
import '../../state/detection_preference_controller.dart';
import '../../state/window_content.dart';
import '../../theme/mq_colors.dart';
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
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell>
    with WidgetsBindingObserver {
  final CanvasController _canvas = CanvasController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachCanvasPrefs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The canvas debounces link-emit / focus snapshots; write them before the
    // app can be suspended or killed.
    if (state != AppLifecycleState.resumed) _canvas.flushPersist();
  }

  Future<void> _attachCanvasPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _canvas.attachPrefs(prefs);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _canvas.dispose();
    super.dispose();
  }

  /// Shared paste-detect logic used by both the canvas key handler and the
  /// menubar Edit → Paste & Detect item.
  Future<void> _pasteOpen() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final List<DetectionMatch<Object?>> matches =
        DetectionPreferenceScope.of(context).rank(
          UtilityCatalog.detectArtifacts(
            text,
            provenance: ArtifactProvenance.clipboard,
          ),
        );
    if (matches.isEmpty) return;
    _canvas.openTool(
      UtilityCatalog.byId(matches.first.primaryToolId),
      seed: matches.first.artifact.rawValue,
    );
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
    // Any rebuild under the host's LayoutBuilder (e.g. a card's geometry
    // builder) relays it out and repaints up to the nearest boundary; this one
    // keeps the menubar, dock and shell chrome out of that repaint.
    return RepaintBoundary(child: _scaffold(c));
  }

  Widget _scaffold(MqColors c) {
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
                // Contains canvas repaints (drags, pan) so the wallpaper,
                // dock and menubar aren't re-recorded with it.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: DesktopCanvas(controller: _canvas),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MqSpacing.md,
                  child: Center(child: _DesktopDockHost(controller: _canvas)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _DockCardState = ({int id, String contentId, bool minimized});

class _DesktopDockHost extends StatefulWidget {
  const _DesktopDockHost({required this.controller});

  final CanvasController controller;

  @override
  State<_DesktopDockHost> createState() => _DesktopDockHostState();
}

class _DesktopDockHostState extends State<_DesktopDockHost> {
  late int? _focusedId;
  late List<_DockCardState> _cards;

  @override
  void initState() {
    super.initState();
    _readState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_DesktopDockHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChange);
    _readState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _readState() {
    _focusedId = widget.controller.focusedId;
    _cards = _cardStates();
  }

  void _onChange() {
    final int? focusedId = widget.controller.focusedId;
    final List<_DockCardState> cards = _cardStates();
    if (!mounted || (_focusedId == focusedId && listEquals(_cards, cards))) {
      return;
    }
    setState(() {
      _focusedId = focusedId;
      _cards = cards;
    });
  }

  List<_DockCardState> _cardStates() => <_DockCardState>[
    for (final CanvasCard card in widget.controller.cards)
      (
        id: card.id,
        contentId: card.content.persistId,
        minimized: card.minimized,
      ),
  ];

  @override
  Widget build(BuildContext context) =>
      DesktopDock(controller: widget.controller);
}
