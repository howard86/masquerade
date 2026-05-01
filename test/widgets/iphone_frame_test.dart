import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mb_colors.dart';
import 'package:masquerade/theme/mb_theme.dart';
import 'package:masquerade/widgets/iphone_frame.dart';

Widget _harness(Widget child) {
  return CupertinoApp(
    home: MBTheme(
      tokens: MBTokens(colors: MBColors.light(), brightness: Brightness.light),
      child: ResponsiveLayout(child: child),
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
    });

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
