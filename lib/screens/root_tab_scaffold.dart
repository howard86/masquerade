import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../state/view_mode_controller.dart';
import '../theme/mq_theme.dart';
import '../utils/shell_layout.dart';
import '../widgets/mq/mq_icons.dart';
import 'desktop/desktop_shell.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class RootTabScaffold extends StatefulWidget {
  const RootTabScaffold({super.key, this.isWebOverride});

  /// See `MyApp.isWebOverride`. Null in production → reads [kIsWeb].
  final bool? isWebOverride;

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
          return const DesktopShell();
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
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(MqIcons.history),
            ),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(MqIcons.setting),
            ),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) => switch (index) {
            0 => const HomeScreen(),
            1 => const HistoryScreen(),
            _ => const SettingsScreen(),
          },
        );
      },
    );
  }
}
