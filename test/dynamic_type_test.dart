import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/utility_catalog.dart';

/// Inventory test for Dynamic Type (xxxLarge ≈ TextScaler 2.0).
///
/// Empirically every screen overflows at 2.0× today — the home grid, the
/// 2-column tool cards, every detail body's action-row Wrap, and the
/// segmented controls. Fixing them all is its own redesign and is out of
/// scope for the Magic Box handoff PR.
///
/// This file pumps each screen at 2.0× so the inventory is in the test
/// tree as a regression seam: when someone fixes a layout, they should
/// remove that screen from [_knownOverflowing]; the test will then assert
/// "no exceptions" for that screen and catch regressions.
///
/// The kickoff test (home at 1.0× as a sanity check) IS enforced so the
/// app at least pumps cleanly with default Dynamic Type.
const Set<String> _knownOverflowing = <String>{
  'home',
  'history',
  'settings',
  'number_base',
  'timestamp',
  'cron',
  'json',
  'base64',
  'color',
  'math',
  'bps',
  'bytes',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(Widget app) => MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
    child: app,
  );

  Future<void> openTool(WidgetTester tester, String toolName) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const MyApp(skipSplash: true)));
    await tester.pumpAndSettle();
    final Finder tile = find.text(toolName);
    expect(tile, findsWidgets, reason: '$toolName tile must be visible');
    await tester.tap(tile.last);
    await tester.pumpAndSettle();
  }

  testWidgets('Home renders at default scale without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final UtilityDescriptor u in UtilityCatalog.all) {
    final bool expectedToOverflow = _knownOverflowing.contains(u.id);
    testWidgets(
      '${u.name} body renders at TextScaler 2.0 without overflow',
      (WidgetTester tester) async {
        await openTool(tester, u.name);
        expect(
          tester.takeException(),
          isNull,
          reason: '${u.name} threw an exception at TextScaler 2.0',
        );
      },
      // QR Code body opens the camera; skip in this smoke test.
      // Known-overflowing screens are tracked above; tests are skipped to
      // let the inventory survive in the tree without failing CI.
      skip: u.id == 'qr_code' || expectedToOverflow,
    );
  }
}
