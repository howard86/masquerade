import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktop = Size(1200, 900);

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      isWebOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DesktopIconGrid', () {
    testWidgets('renders tiles for all catalog tools', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
      // Each tool name should appear as a label.
      for (final UtilityDescriptor d in UtilityCatalog.all) {
        expect(find.text(d.name), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('tapping a tile opens a card with the correct tool', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final UtilityDescriptor first = UtilityCatalog.all.first;
      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      // The tool card frame should now be visible.
      expect(
        find.text(first.name),
        findsAtLeastNWidgets(2), // icon label + card title
      );
    });
  });
}
