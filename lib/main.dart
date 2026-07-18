import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'state/history_controller.dart';
import 'state/theme_controller.dart';
import 'state/view_mode_controller.dart';

Future<void> main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  // Hold the native splash so we can hand off to MqSplashScreen and
  // crossfade into the shell — no white flash between native and Dart.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
    ThemeController.load(),
    HistoryController.load(),
    ViewModeController.load(),
  ]);
  runApp(
    MyApp(
      themeController: loaded[0] as ThemeController,
      historyController: loaded[1] as HistoryController,
      viewModeController: loaded[2] as ViewModeController,
    ),
  );
}

void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'IBM Plex Mono',
      'IBM Plex Sans',
      'IBM Plex Serif',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}
