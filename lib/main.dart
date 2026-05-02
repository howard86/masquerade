import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'state/history_controller.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
    ThemeController.load(),
    HistoryController.load(),
  ]);
  runApp(
    MyApp(
      themeController: loaded[0] as ThemeController,
      historyController: loaded[1] as HistoryController,
    ),
  );
}
