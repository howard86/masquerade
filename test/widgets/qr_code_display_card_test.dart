import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/qr_code_display_card.dart';

void main() {
  group('QrCodeDisplayCard', () {
    late DateTime testScanTime;
    late String testScannedData;

    setUp(() {
      testScanTime = DateTime(2024, 1, 15, 14, 30, 45);
      testScannedData = 'https://example.com/qr-code-data';
    });

    testWidgets('displays QR code scan information correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: testScannedData,
            scanTime: testScanTime,
          ),
        ),
      );

      // Verify the card title
      expect(find.text('QR Code Scanned'), findsOneWidget);

      // Verify the scan time is displayed
      expect(find.text('Scanned at 14:30:45'), findsOneWidget);

      // Verify the scanned data is displayed
      expect(find.text('Scanned Data:'), findsOneWidget);
      expect(find.text(testScannedData), findsOneWidget);

      // Verify character count is displayed
      expect(find.text('${testScannedData.length} characters'), findsOneWidget);

      // Verify QR icon is present
      expect(find.byIcon(CupertinoIcons.qrcode), findsOneWidget);
    });

    testWidgets('displays different scan times correctly', (
      WidgetTester tester,
    ) async {
      final morningTime = DateTime(2024, 1, 15, 9, 5, 30);
      final eveningTime = DateTime(2024, 1, 15, 23, 59, 59);

      // Test morning time
      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: testScannedData,
            scanTime: morningTime,
          ),
        ),
      );

      expect(find.text('Scanned at 09:05:30'), findsOneWidget);

      // Test evening time
      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: testScannedData,
            scanTime: eveningTime,
          ),
        ),
      );

      expect(find.text('Scanned at 23:59:59'), findsOneWidget);
    });

    testWidgets('displays different types of scanned data', (
      WidgetTester tester,
    ) async {
      final testCases = [
        'Simple text',
        'https://www.example.com/very/long/url/path',
        '1234567890',
        '{"json": "data", "value": 42}',
        'Very long text that might wrap to multiple lines and should still be displayed correctly without any issues',
      ];

      for (final data in testCases) {
        await tester.pumpWidget(
          CupertinoApp(
            home: QrCodeDisplayCard(scannedData: data, scanTime: testScanTime),
          ),
        );

        // Verify the data is displayed
        expect(find.text(data), findsOneWidget);

        // Verify character count is correct
        expect(find.text('${data.length} characters'), findsOneWidget);
      }
    });

    testWidgets('handles empty scanned data', (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(scannedData: '', scanTime: testScanTime),
        ),
      );

      // Should still display the card structure
      expect(find.text('QR Code Scanned'), findsOneWidget);
      expect(find.text('Scanned Data:'), findsOneWidget);
      expect(find.text('0 characters'), findsOneWidget);
    });

    testWidgets('applies correct styling and layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: testScannedData,
            scanTime: testScanTime,
          ),
        ),
      );

      // Verify the card has proper styling
      final cardContainer = find.byType(Container).first;
      expect(cardContainer, findsOneWidget);

      // Verify the QR icon container has blue background
      final iconContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                CupertinoColors.systemBlue.withValues(alpha: 0.1),
      );
      expect(iconContainer, findsOneWidget);

      // Verify the scanned data container has grey background
      final dataContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                CupertinoColors.systemGrey6,
      );
      expect(dataContainer, findsOneWidget);
    });

    testWidgets('displays special characters correctly', (
      WidgetTester tester,
    ) async {
      final specialData = 'Special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?';

      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: specialData,
            scanTime: testScanTime,
          ),
        ),
      );

      expect(find.text(specialData), findsOneWidget);
      expect(find.text('${specialData.length} characters'), findsOneWidget);
    });

    testWidgets('handles multiline scanned data', (WidgetTester tester) async {
      final multilineData = 'Line 1\nLine 2\nLine 3';

      await tester.pumpWidget(
        CupertinoApp(
          home: QrCodeDisplayCard(
            scannedData: multilineData,
            scanTime: testScanTime,
          ),
        ),
      );

      expect(find.text(multilineData), findsOneWidget);
      expect(find.text('${multilineData.length} characters'), findsOneWidget);
    });
  });
}
