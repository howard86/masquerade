import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_frame/device_frame.dart';
import 'package:magic_box/widgets/iphone_frame.dart';

void main() {
  group('ResponsiveLayout', () {
    testWidgets('shows device frame on large screens', (
      WidgetTester tester,
    ) async {
      // Simulate a large screen (larger than iPhone Pro + 100px buffer)
      await tester.binding.setSurfaceSize(const Size(1200, 1000));

      await tester.pumpWidget(
        const MaterialApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      // Should find the test content
      expect(find.text('Test Content'), findsOneWidget);

      // Should find the device frame
      expect(find.byType(DeviceFrame), findsOneWidget);
    });

    testWidgets('shows content directly on small screens', (
      WidgetTester tester,
    ) async {
      // Simulate a small screen (smaller than iPhone Pro)
      await tester.binding.setSurfaceSize(const Size(300, 600));

      await tester.pumpWidget(
        const MaterialApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      // Should find the test content
      expect(find.text('Test Content'), findsOneWidget);

      // Should NOT find the device frame
      expect(find.byType(DeviceFrame), findsNothing);
    });

    testWidgets('uses iPhone 13 Pro device', (WidgetTester tester) async {
      // Simulate a large screen
      await tester.binding.setSurfaceSize(const Size(1200, 1000));

      await tester.pumpWidget(
        const MaterialApp(home: ResponsiveLayout(child: Text('Test Content'))),
      );

      // Should find the device frame
      final deviceFrame = tester.widget<DeviceFrame>(find.byType(DeviceFrame));
      expect(deviceFrame.device, equals(Devices.ios.iPhone16Pro));
      expect(deviceFrame.isFrameVisible, isTrue);
      expect(deviceFrame.orientation, equals(Orientation.portrait));
    });
  });
}
