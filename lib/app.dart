import 'package:flutter/cupertino.dart';

import 'screens/root_tab_scaffold.dart';
import 'state/history_controller.dart';
import 'state/theme_controller.dart';
import 'theme/mq_colors.dart';
import 'theme/mq_theme.dart';
import 'widgets/iphone_frame.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.themeController, this.historyController});

  final ThemeController? themeController;
  final HistoryController? historyController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final ThemeController _theme;
  late final HistoryController _history;

  Brightness _platformBrightness = Brightness.light;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeController ?? ThemeController();
    _history = widget.historyController ?? HistoryController();
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

  Brightness _resolveBrightness(MqThemeMode mode) => switch (mode) {
    MqThemeMode.light => Brightness.light,
    MqThemeMode.dark => Brightness.dark,
    MqThemeMode.system => _platformBrightness,
  };

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: HistoryScope(
        controller: _history,
        child: ListenableBuilder(
          listenable: _theme,
          builder: (BuildContext context, _) {
            final Brightness brightness = _resolveBrightness(_theme.mode);
            final MqColors colors = brightness == Brightness.dark
                ? MqColors.dark()
                : MqColors.light();
            final MqTokens tokens = MqTokens(
              colors: colors,
              brightness: brightness,
            );
            return CupertinoApp(
              debugShowCheckedModeBanner: false,
              title: 'Masquerade',
              theme: buildCupertinoTheme(brightness),
              builder: (BuildContext context, Widget? child) => MqTheme(
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
    );
  }
}
