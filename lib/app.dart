import 'package:flutter/cupertino.dart';

import 'screens/root_tab_scaffold.dart';
import 'state/favorites_controller.dart';
import 'state/history_controller.dart';
import 'state/theme_controller.dart';
import 'theme/mb_colors.dart';
import 'theme/mb_theme.dart';
import 'widgets/iphone_frame.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.themeController,
    this.historyController,
    this.favoritesController,
  });

  final ThemeController? themeController;
  final HistoryController? historyController;
  final FavoritesController? favoritesController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final ThemeController _theme;
  late final HistoryController _history;
  late final FavoritesController _favorites;

  Brightness _platformBrightness = Brightness.light;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeController ?? ThemeController();
    _history = widget.historyController ?? HistoryController();
    _favorites = widget.favoritesController ?? FavoritesController();
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final Brightness next =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next != _platformBrightness) {
      setState(() => _platformBrightness = next);
    }
  }

  Brightness _resolveBrightness(MBThemeMode mode) => switch (mode) {
    MBThemeMode.light => Brightness.light,
    MBThemeMode.dark => Brightness.dark,
    MBThemeMode.system => _platformBrightness,
  };

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: HistoryScope(
        controller: _history,
        child: FavoritesScope(
          controller: _favorites,
          child: ListenableBuilder(
            listenable: _theme,
            builder: (BuildContext context, _) {
              final Brightness brightness = _resolveBrightness(_theme.mode);
              final MBColors colors = brightness == Brightness.dark
                  ? MBColors.dark()
                  : MBColors.light();
              final MBTokens tokens = MBTokens(
                colors: colors,
                brightness: brightness,
              );
              return CupertinoApp(
                debugShowCheckedModeBanner: false,
                title: 'Masquerade — Magic Box',
                theme: buildCupertinoTheme(brightness),
                builder: (BuildContext context, Widget? child) => MBTheme(
                  tokens: tokens,
                  child: ResponsiveLayout(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: const RootTabScaffold(),
              );
            },
          ),
        ),
      ),
    );
  }
}
