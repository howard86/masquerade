import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'state/history_controller.dart';
import 'state/detection_preference_controller.dart';
import 'state/library_controller.dart';
import 'state/share_inbox_controller.dart';
import 'state/theme_controller.dart';
import 'state/tool_draft_controller.dart';
import 'state/view_mode_controller.dart';
import 'state/work_session_controller.dart';

Future<void> main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  // Hold the native splash so we can hand off to MqSplashScreen and
  // crossfade into the shell — no white flash between native and Dart.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
    ThemeController.load(),
    HistoryController.load(),
    LibraryController.load(),
    ViewModeController.load(),
    DetectionPreferenceController.load(),
    ToolDraftController.load(),
    WorkSessionController.load(),
    ShareInboxController.load(),
  ]);
  runApp(
    MyApp(
      themeController: loaded[0] as ThemeController,
      historyController: loaded[1] as HistoryController,
      libraryController: loaded[2] as LibraryController,
      viewModeController: loaded[3] as ViewModeController,
      detectionPreferenceController: loaded[4] as DetectionPreferenceController,
      toolDraftController: loaded[5] as ToolDraftController,
      workSessionController: loaded[6] as WorkSessionController,
      shareInboxController: loaded[7] as ShareInboxController,
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
