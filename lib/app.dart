import 'package:flutter/cupertino.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'screens/root_tab_scaffold.dart';
import 'state/density_controller.dart';
import 'state/history_controller.dart';
import 'state/theme_controller.dart';
import 'state/view_mode_controller.dart';
import 'state/wallpaper_controller.dart';
import 'theme/mq_colors.dart';
import 'theme/mq_theme.dart';
import 'widgets/iphone_frame.dart';
import 'widgets/mq/mq_splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.themeController,
    this.historyController,
    this.densityController,
    this.viewModeController,
    this.isWebOverride,
    this.skipSplash = false,
  });

  final ThemeController? themeController;
  final HistoryController? historyController;
  final DensityController? densityController;
  final ViewModeController? viewModeController;

  /// Test seam for the web-gated desktop shell. `kIsWeb` is always false under
  /// `flutter test`, so widget tests pass `true` here to exercise the desktop
  /// path. Null in production — the shell reads `kIsWeb` directly.
  final bool? isWebOverride;

  /// Tests pump `MyApp` directly without going through `main.dart`'s
  /// `FlutterNativeSplash.preserve()`, so the splash crossfade adds 600 ms
  /// of timer noise without exercising any production code path. Set true
  /// from test helpers to skip straight to the shell.
  final bool skipSplash;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// Time the Dart splash stays on screen before crossfading to the
  /// shell. The native splash dismisses at the start of this window so
  /// the handoff is invisible.
  static const Duration _splashHold = Duration(milliseconds: 350);
  static const Duration _splashFade = Duration(milliseconds: 250);

  late final ThemeController _theme;
  late final HistoryController _history;
  late final DensityController _density;
  late final ViewModeController _viewMode;
  late final WallpaperController _wallpaper;
  late final Listenable _appListenable;

  Brightness _platformBrightness = Brightness.light;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeController ?? ThemeController();
    _history = widget.historyController ?? HistoryController();
    _density = widget.densityController ?? DensityController();
    _viewMode = widget.viewModeController ?? ViewModeController();
    _wallpaper = WallpaperController();
    _attachWallpaperPrefs();
    // _viewMode is intentionally absent: it drives layout solely through
    // ViewModeScope (an InheritedNotifier), so toggling rebuilds only the
    // layout consumers — not the whole CupertinoApp this builder produces.
    _appListenable = Listenable.merge(<Listenable>[_theme, _density]);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    WidgetsBinding.instance.addObserver(this);
    _showSplash = !widget.skipSplash;
    if (!widget.skipSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Dart splash now painted — release the native overlay and start
        // the hold timer for the crossfade.
        FlutterNativeSplash.remove();
        Future<void>.delayed(_splashHold, () {
          if (mounted) setState(() => _showSplash = false);
        });
      });
    }
  }

  Future<void> _attachWallpaperPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String? raw = prefs.getString('mb.wallpaper.type');
    if (raw != null) {
      final MqWallpaperType? type = MqWallpaperType.values
          .cast<MqWallpaperType?>()
          .firstWhere((t) => t!.name == raw, orElse: () => null);
      if (type != null) {
        _wallpaper.setType(type);
      }
    }
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
    return ViewModeScope(
      controller: _viewMode,
      child: ThemeScope(
        controller: _theme,
        child: DensityScope(
          controller: _density,
          child: HistoryScope(
            controller: _history,
            child: WallpaperScope(
              controller: _wallpaper,
              child: ListenableBuilder(
                listenable: _appListenable,
                builder: (BuildContext context, _) {
                  final Brightness brightness = _resolveBrightness(_theme.mode);
                  final MqColors colors = brightness == Brightness.dark
                      ? MqColors.dark()
                      : MqColors.light();
                  final MqTokens tokens = MqTokens(
                    colors: colors,
                    brightness: brightness,
                    density: _density.density,
                  );
                  return CupertinoApp(
                    debugShowCheckedModeBanner: false,
                    title: 'Masquerade',
                    theme: buildCupertinoTheme(brightness),
                    builder: (BuildContext context, Widget? child) => MqTheme(
                      tokens: tokens,
                      child: ResponsiveLayout(
                        isWebOverride: widget.isWebOverride,
                        child: AnimatedSwitcher(
                          duration: _splashFade,
                          child: _showSplash
                              ? const MqSplashScreen(
                                  key: ValueKey<String>('splash'),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey<String>('shell'),
                                  child: child ?? const SizedBox.shrink(),
                                ),
                        ),
                      ),
                    ),
                    home: RootTabScaffold(isWebOverride: widget.isWebOverride),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
