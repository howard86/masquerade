import 'package:flutter/cupertino.dart';

import '../theme/mq_theme.dart';
import '../widgets/mq/mq_icons.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class RootTabScaffold extends StatefulWidget {
  const RootTabScaffold({super.key});

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
    final c = context.mq.colors;
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: c.surface.withValues(alpha: 0.85),
        activeColor: c.accent,
        inactiveColor: c.textTer,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(MqIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(MqIcons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(MqIcons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(MqIcons.setting),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) => switch (index) {
            0 => const HomeScreen(),
            1 => const SearchScreen(),
            2 => const HistoryScreen(),
            _ => const SettingsScreen(),
          },
        );
      },
    );
  }
}
