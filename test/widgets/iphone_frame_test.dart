import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/iphone_frame.dart';

void main() {
  group('ResponsiveLayout', () {
    testWidgets('shows iPhone frame on large screens', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const CupertinoApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(IphoneFrame), findsOneWidget);
    });

    testWidgets('shows content directly on small screens', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const CupertinoApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(IphoneFrame), findsNothing);
    });

    testWidgets('renders iPhone 16 Pro silhouette geometry', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const CupertinoApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      expect(
        tester.getSize(find.byType(IphoneFrame)),
        equals(const Size(393, 852)),
      );
      expect(
        find.byKey(const ValueKey<String>('iphone_frame_dynamic_island')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('iphone_frame_home_indicator')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('iphone_frame_screen')),
          matching: find.text('Test Content'),
        ),
        findsOneWidget,
      );
    });
  });
}
