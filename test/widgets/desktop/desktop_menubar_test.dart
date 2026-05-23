import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
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

  group('DesktopMenubar', () {
    testWidgets('Close All clears open cards', (WidgetTester tester) async {
      await _pump(tester);
      // Open a card first via icon tile.
      final String firstName = UtilityCatalog.all.first.name;
      await tester.tap(find.text(firstName));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);

      // File → Close All.
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close All').last);
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsNothing);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
    });

    testWidgets('Mobile view fires the view-mode change', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.byType(DesktopShell), findsOneWidget);

      await tester.tap(find.text('⏻ Masquerade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile view'));
      await tester.pumpAndSettle();
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });

    testWidgets('⏻ → History… opens the History dialog', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('⏻ Masquerade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History…'));
      await tester.pumpAndSettle();
      // The full-screen dialog wrapper shows a "Done" control to dismiss.
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('displays a live clock', (WidgetTester tester) async {
      await _pump(tester);
      // The clock should show the current time in HH:MM format.
      final DateTime now = DateTime.now();
      final String h = now.hour.toString().padLeft(2, '0');
      final String m = now.minute.toString().padLeft(2, '0');
      expect(find.text('$h:$m'), findsOneWidget);
    });
  });
}
