import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/app.dart';

/// Below `ResponsiveLayout`'s 493x1052 threshold so `MyApp` skips the
/// iPhone-frame wrap that constrains content to 393 logical wide and breaks
/// any 3-button bottom bar.
const Size kDetailSurfaceSize = Size(480, 1050);

/// Longest debounce in any detail screen is 200 ms (`bps`/`color`/`number_base`/
/// `json`); 300 ms guarantees the timer has fired before assertions run.
const Duration kDebouncePump = Duration(milliseconds: 300);

/// Pumps the full app, navigates to the tool whose home-grid tile carries
/// [tileLabel], and waits for the detail screen to settle.
Future<void> pumpHomeAndOpen(WidgetTester tester, String tileLabel) async {
  await tester.binding.setSurfaceSize(kDetailSurfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  final Finder tile = find.text(tileLabel).last;
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
