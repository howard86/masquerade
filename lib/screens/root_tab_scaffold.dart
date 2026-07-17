import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../state/view_mode_controller.dart';
import '../state/library_controller.dart';
import '../theme/mq_theme.dart';
import '../utils/shell_layout.dart';
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
    required this.libraryController,
  });

  /// See `MyApp.isWebOverride`. Null in production → reads [kIsWeb].
  final bool? isWebOverride;
  final LibraryController libraryController;

  @override
  State<RootTabScaffold> createState() => _RootTabScaffoldState();
}

class _RootTabScaffoldState extends State<RootTabScaffold> {
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = widget.isWebOverride ?? kIsWeb;
    final MqViewMode viewMode = ViewModeScope.of(context).mode;
    // Measure actual available space via LayoutBuilder (not MediaQuery) so the
    // decision matches ResponsiveLayout's and stays correct when this scaffold
    // is nested inside the iPhone frame (which constrains it to 393 wide).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MqShellLayout layout = resolveShellLayout(
          isWeb: isWeb,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          viewMode: viewMode,
        );
        if (layout == MqShellLayout.desktop) {
          return DesktopShell(isWebOverride: widget.isWebOverride);
        }
        return _buildTabScaffold(context);
      },
    );
  }

  Widget _buildTabScaffold(BuildContext context) {
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
              0 => HomeScreen(navigationBar: navigationBar),
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
              builder: (_) =>
                  SettingsScreen(isWebOverride: widget.isWebOverride),
            ),
          ),
          child: const Icon(MqIcons.setting),
        ),
      ),
    );
  }
}
