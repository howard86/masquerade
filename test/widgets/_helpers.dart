import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/state/history_controller.dart';

/// Surface size used by inline-card home tests. Matches `kDetailSurfaceSize`
/// from `test/widgets/tool_bodies/_helpers.dart` — kept large enough that
/// `ResponsiveLayout` skips the iPhone-frame wrap that would constrain
/// content to 393 logical wide.
const Size kHomeSurfaceSize = Size(480, 1050);

/// Pumps `MyApp` with a `HistoryController` hydrated from the mocked
/// `SharedPreferences`. The default `const MyApp()` constructs a fresh
/// `HistoryController` that never touches prefs, so any test that pre-seeds
/// `mb.history.entries` must use this helper to see those entries.
Future<HistoryController> pumpHomeWithLoadedHistory(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(kHomeSurfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final HistoryController history = await HistoryController.load();
  await tester.pumpWidget(MyApp(historyController: history, skipSplash: true));
  await tester.pumpAndSettle();
  return history;
}

/// Encodes a list of entry maps the way `HistoryController.load()` expects.
String encodeHistoryEntries(List<Map<String, Object>> entries) =>
    jsonEncode(entries);

/// Builds an entry-map shaped like `HistoryEntry.toJson()` — fills in
/// reasonable defaults so callers only specify what they care about.
Map<String, Object> historyEntry({
  required String utilityId,
  String input = 'x',
  String output = 'y',
  bool sensitive = false,
  int? ts,
}) => <String, Object>{
  'utilityId': utilityId,
  'input': input,
  'output': output,
  'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
  'sensitive': sensitive,
};
