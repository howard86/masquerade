import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

/// Inventory test for Dynamic Type (xxxLarge ≈ TextScaler 2.0).
///
/// Every tab and every tool body must pump at 2.0× without throwing a
/// `RenderFlex` overflow. The home grid grows its cards with the text scale,
/// the chip rows use `Wrap`, and the settings rows let their labels flex, so
/// the layouts survive large Dynamic Type. If a future change reintroduces an
/// overflow, the matching test below fails.
///
/// QR Code opens the camera, so it is skipped in this smoke test.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(Widget app) => MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
    child: app,
  );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const MyApp(skipSplash: true)));
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

  for (final String tab in <String>['Home', 'History', 'Settings']) {
    testWidgets('$tab tab renders at TextScaler 2.0 without overflow', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab tab threw an exception at TextScaler 2.0',
      );
    });
  }

  for (final UtilityDescriptor u in UtilityCatalog.all) {
    testWidgets(
      '${u.name} body renders at TextScaler 2.0 without overflow',
      (WidgetTester tester) async {
        await pumpApp(tester);
        final Finder tile = find.text(u.name).last;
        expect(tile, findsWidgets, reason: '${u.name} tile must be visible');
        // The grid is tall at 2×, so the tile may sit below the fold; scroll it
        // into view before tapping so the body actually opens.
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${u.name} threw an exception at TextScaler 2.0',
        );
      },
      // QR Code body opens the camera; skip in this smoke test.
      skip: u.id == 'qr_code',
    );
  }

  // Accessibility teeth for the overflow guard above: a tool body could ship a
  // bare output cell (an `MqMonoCell` with no copy affordance label) and still
  // pass the overflow checks. Every copyable cell wraps its copy button in a
  // `Semantics(label: 'Copy …')` (see `MqMonoCell`), so for every copyable cell
  // a body renders there must be at least one matching copy label. This locks
  // in the merged Semantics work (TB-01/TB-05) across the whole catalog: a
  // future copyable cell that drops its label would leave fewer `Copy …` labels
  // than copyable cells and fail here.
  for (final UtilityDescriptor u in UtilityCatalog.all) {
    testWidgets(
      '${u.name} output cells expose copy Semantics labels',
      (WidgetTester tester) async {
        await pumpApp(tester);
        final Finder tile = find.text(u.name).last;
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();

        // Count only the cells that advertise a copy affordance; cells built
        // with `copyable: false` (errors, hints) legitimately have no label.
        final Iterable<MqMonoCell> copyableCells = tester
            .widgetList<MqMonoCell>(find.byType(MqMonoCell))
            .where((MqMonoCell cell) => cell.copyable);

        // Bodies that render no copyable output at their initial state have
        // nothing to assert — the guard is over the cells that ARE present.
        if (copyableCells.isEmpty) return;

        final Finder copyLabels = find.bySemanticsLabel(RegExp(r'^Copy '));
        expect(
          copyLabels,
          findsAtLeastNWidgets(copyableCells.length),
          reason:
              '${u.name} rendered ${copyableCells.length} copyable MqMonoCell(s) '
              'but fewer carried a "Copy …" Semantics label',
        );
      },
      // QR Code body opens the camera; skip as in the overflow smoke test.
      skip: u.id == 'qr_code',
    );
  }
}
