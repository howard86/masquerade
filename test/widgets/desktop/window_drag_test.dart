import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';

void main() {
  testWidgets(
    'window applies every pointer delta and snaps from final bounds',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MyApp(
          desktopShellOverride: true,
          viewModeController: ViewModeController(),
          skipSplash: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('UUID'));
      await tester.pumpAndSettle();

      final Finder window = find.byType(ToolCardFrame);
      final Offset beforeDrag = tester.getTopLeft(window);
      final TestGesture gesture = await tester.startGesture(
        beforeDrag + const Offset(180, 18),
      );
      await gesture.moveBy(const Offset(20, 20));
      await gesture.moveBy(const Offset(40, 30));
      await gesture.moveBy(const Offset(40, 30));
      await gesture.up();
      await tester.pump();

      expect(tester.getTopLeft(window), beforeDrag + const Offset(100, 80));

      final TestGesture snapGesture = await tester.startGesture(
        tester.getTopLeft(window) + const Offset(180, 18),
      );
      await snapGesture.moveBy(const Offset(-20, 0));
      await snapGesture.moveBy(const Offset(-56, 0));
      await snapGesture.moveBy(const Offset(-56, 0));
      await snapGesture.up();
      await tester.pump();

      expect(tester.getTopLeft(window).dx, 0);
      expect(tester.getSize(window).width, 600);
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
