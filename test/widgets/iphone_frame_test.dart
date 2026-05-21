import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
import 'package:masquerade/widgets/mq/view_mode_toggle_button.dart';

Widget _harness(
  Widget child, {
  bool? isWeb,
  MqViewMode initial = MqViewMode.desktop,
}) {
  return CupertinoApp(
    home: ViewModeScope(
      controller: ViewModeController(initial: initial),
      child: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: ResponsiveLayout(isWebOverride: isWeb, child: child),
      ),
    ),
  );
}

void main() {
  group('ResponsiveLayout', () {
    testWidgets('shows iPhone frame on large screens', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(const Text('Test Content')));

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(IphoneFrame), findsOneWidget);
      // No web override → kIsWeb is false in tests → no toggle.
      expect(find.byKey(ViewModeToggleButton.compactKey), findsNothing);
    });

    testWidgets(
      'on wide web, the compact toggle sits in the frame status strip',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _harness(
            const Text('Test Content'),
            isWeb: true,
            initial: MqViewMode.mobile,
          ),
        );

        final Finder toggle = find.byKey(ViewModeToggleButton.compactKey);
        expect(toggle, findsOneWidget);
        expect(find.byType(IphoneFrame), findsOneWidget);

        final Rect chip = tester.getRect(toggle);
        final Rect screen = tester.getRect(find.byKey(IphoneFrame.screenKey));
        final Rect island = tester.getRect(
          find.byKey(IphoneFrame.dynamicIslandKey),
        );

        // Inside the screen, right of the Dynamic Island, within the top band.
        expect(screen.contains(chip.topLeft), isTrue);
        expect(screen.contains(chip.bottomRight), isTrue);
        expect(chip.left, greaterThan(island.right));
        expect(chip.top, lessThan(island.bottom));
      },
    );

    testWidgets('shows content directly on small screens', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(const Text('Test Content')));

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(IphoneFrame), findsNothing);
    });

    testWidgets('renders iPhone 16 Pro silhouette geometry', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(const Text('Test Content')));

      expect(
        tester.getSize(find.byType(IphoneFrame)),
        equals(const Size(IphoneFrame.logicalWidth, IphoneFrame.logicalHeight)),
      );
      expect(find.byKey(IphoneFrame.dynamicIslandKey), findsOneWidget);
      expect(find.byKey(IphoneFrame.homeIndicatorKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(IphoneFrame.screenKey),
          matching: find.text('Test Content'),
        ),
        findsOneWidget,
      );
    });
  });
}
