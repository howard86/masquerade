import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../state/view_mode_controller.dart';
import '../state/library_controller.dart';
import '../state/share_inbox_controller.dart';
import '../theme/mq_theme.dart';
import '../utils/shell_layout.dart';
import '../utils/external_input_importer.dart';
import '../widgets/mq/mq_icons.dart';
import 'desktop/desktop_shell.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class RootTabScaffold extends StatefulWidget {
  const RootTabScaffold({
    super.key,
    this.isWebOverride,
    this.desktopShellOverride,
    required this.libraryController,
    this.externalInputImporter,
    this.qrScanner,
  });

  /// See `MyApp.isWebOverride`. Null in production → reads [kIsWeb].
  final bool? isWebOverride;

  /// See `MyApp.desktopShellOverride`.
  final bool? desktopShellOverride;

  final LibraryController libraryController;
  final ExternalInputImporter? externalInputImporter;
  final Future<String?> Function(BuildContext context)? qrScanner;

  @override
  State<RootTabScaffold> createState() => _RootTabScaffoldState();
}

class _RootTabScaffoldState extends State<RootTabScaffold> {
  late final CupertinoTabController _tabController;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    3,
    (_) => GlobalKey<NavigatorState>(),
  );
  int _handledExternalInputRevision = 0;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ShareInboxController inbox = ShareInboxScope.of(context);
    if (inbox.externalInputRevision > _handledExternalInputRevision) {
      _handledExternalInputRevision = inbox.externalInputRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusWorkbench();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = widget.isWebOverride ?? kIsWeb;
    final bool desktopSupported = desktopShellSupported(
      override: widget.desktopShellOverride ?? widget.isWebOverride,
    );
    final MqViewMode viewMode = ViewModeScope.of(context).mode;
    // Measure actual available space via LayoutBuilder (not MediaQuery) so the
    // decision matches ResponsiveLayout's and stays correct when this scaffold
    // is nested inside the iPhone frame (which constrains it to 393 wide).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MqShellLayout layout = resolveShellLayout(
          desktopSupported: desktopSupported,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          viewMode: viewMode,
        );
        if (layout == MqShellLayout.desktop) {
          return const DesktopShell();
        }
        return _buildTabScaffold(context, importEnabled: !isWeb);
      },
    );
  }

  Widget _buildTabScaffold(
    BuildContext context, {
    required bool importEnabled,
  }) {
    final c = context.mq.colors;
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: c.surface.withValues(alpha: 0.85),
        activeColor: c.accent,
        inactiveColor: c.textTer,
        height: 68,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(MqIcons.home),
            ),
            label: 'Workbench',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(MqIcons.list),
            ),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(MqIcons.history),
            ),
            label: 'Activity',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          navigatorKey: _navigatorKeys[index],
          builder: (BuildContext context) {
            final String title = switch (index) {
              0 => 'Workbench',
              1 => 'Library',
              _ => 'Activity',
            };
            final CupertinoNavigationBar navigationBar = _topLevelNavigationBar(
              context,
              title,
            );
            return switch (index) {
              0 => HomeScreen(
                navigationBar: navigationBar,
                externalInputImporter: widget.externalInputImporter,
                importEnabled: importEnabled,
                qrScanner: widget.qrScanner,
                onAppIntentFocus: _focusWorkbench,
              ),
              1 => LibraryScope(
                controller: widget.libraryController,
                child: LibraryScreen(navigationBar: navigationBar),
              ),
              _ => HistoryScreen(
                title: title,
                navigationBar: navigationBar,
                onResume: () => _tabController.index = 0,
              ),
            };
          },
        );
      },
    );
  }

  void _focusWorkbench() {
    _tabController.index = 0;
    _navigatorKeys.first.currentState?.popUntil(
      (Route<void> route) => route.isFirst,
    );
  }

  CupertinoNavigationBar _topLevelNavigationBar(
    BuildContext context,
    String title,
  ) {
    return CupertinoNavigationBar(
      middle: Text(title),
      trailing: Semantics(
        label: 'Open Settings',
        button: true,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: () => Navigator.of(context).push<void>(
            CupertinoPageRoute<void>(
              builder: (_) => SettingsScreen(
                desktopShellOverride:
                    widget.desktopShellOverride ?? widget.isWebOverride,
              ),
            ),
          ),
          child: const Icon(MqIcons.setting),
        ),
      ),
    );
  }
}
