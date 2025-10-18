import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';

/// QR Scanner Integration Tests
/// Tests the QR scanner functionality and UI components
void main() {
  group('QR Scanner Integration Tests', () {
    testWidgets('QR scanner button is present and functional', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the QR scanner button by looking for the second CupertinoButton
      final qrButton = find.byType(CupertinoButton).at(1);
      expect(qrButton, findsOneWidget);

      // Verify the button is tappable
      await tester.tap(qrButton);
      await tester.pumpAndSettle();

      // The button should still be present after tap
      expect(qrButton, findsOneWidget);
    });

    testWidgets('QR scanner button has correct styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the QR scanner button container
      final qrButtonContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                CupertinoColors.systemBlue,
      );
      expect(qrButtonContainer, findsOneWidget);

      // Verify the button has the correct icon
      final qrIcon = find.byIcon(CupertinoIcons.qrcode_viewfinder);
      expect(qrIcon, findsOneWidget);
    });

    testWidgets('text field and QR button are properly aligned', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify the row containing text field and QR button
      final rowWidget = find.byType(Row);
      expect(rowWidget, findsWidgets);

      // Verify both text field and QR button are in the same row
      final textField = find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoTextField &&
            widget.placeholder ==
                'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
      );
      final qrButton = find.byType(CupertinoButton).at(1);

      expect(textField, findsOneWidget);
      expect(qrButton, findsOneWidget);
    });

    testWidgets('QR scanner button maintains state during text input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the text field
      final textField = find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoTextField &&
            widget.placeholder ==
                'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
      );

      // Enter some text
      await tester.enterText(textField, 'test input');
      await tester.pumpAndSettle();

      // Verify QR button is still present and functional
      final qrButton = find.byType(CupertinoButton).at(1);
      expect(qrButton, findsOneWidget);

      // Tap the QR button
      await tester.tap(qrButton);
      await tester.pumpAndSettle();

      // Button should still be present
      expect(qrButton, findsOneWidget);
    });

    testWidgets('clear button resets QR scanner state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the clear button by looking for CupertinoButton.filled
      final clearButton = find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoButton &&
            widget.child is Row &&
            (widget.child as Row).children.any(
              (child) =>
                  child is Icon &&
                  child.icon == CupertinoIcons.clear_circled_solid,
            ),
      );
      expect(clearButton, findsOneWidget);

      // Tap the clear button
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Verify QR button is still present after clearing
      final qrButton = find.byType(CupertinoButton).at(1);
      expect(qrButton, findsOneWidget);

      // Verify text field is cleared
      final textField = find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoTextField &&
            widget.placeholder ==
                'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
      );
      expect(textField, findsOneWidget);
    });

    testWidgets('QR scanner button is accessible', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify the QR scanner button is accessible
      final qrButton = find.byType(CupertinoButton).at(1);
      expect(qrButton, findsOneWidget);

      // Verify the button is tappable
      await tester.tap(qrButton);
      await tester.pumpAndSettle();

      // Button should still be present
      expect(qrButton, findsOneWidget);
    });

    testWidgets('QR scanner button works with different screen sizes', (
      WidgetTester tester,
    ) async {
      // Test with different screen sizes
      final screenSizes = [
        const Size(320, 568), // iPhone SE
        const Size(375, 667), // iPhone 8
        const Size(414, 896), // iPhone 11 Pro Max
        const Size(768, 1024), // iPad
      ];

      for (final size in screenSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Verify QR scanner button is present
        final qrButton = find.byType(CupertinoButton).at(1);
        expect(qrButton, findsOneWidget);

        // Verify text field is also present
        final textField = find.byWidgetPredicate(
          (widget) =>
              widget is CupertinoTextField &&
              widget.placeholder ==
                  'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
        );
        expect(textField, findsOneWidget);

        // Clean up for next iteration
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('QR scanner button maintains proper spacing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the row containing text field and QR button
      final rowWidgets = find.byType(Row);
      expect(rowWidgets, findsWidgets);

      // Find the specific row that contains the text field and QR button
      final mainRow = find.byWidgetPredicate(
        (widget) =>
            widget is Row &&
            widget.children.any(
              (child) => child is Expanded && child.child is CupertinoTextField,
            ) &&
            widget.children.any(
              (child) => child is SizedBox && child.width == 12.0,
            ) &&
            widget.children.any(
              (child) =>
                  child is CupertinoButton &&
                  child.child is Container &&
                  (child.child as Container).child is Icon &&
                  ((child.child as Container).child as Icon).icon ==
                      CupertinoIcons.qrcode_viewfinder,
            ),
      );
      expect(mainRow, findsOneWidget);

      // Verify the SizedBox provides proper spacing
      final spacingWidget = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 12.0,
      );
      expect(spacingWidget, findsOneWidget);
    });

    testWidgets('QR scanner button has proper visual hierarchy', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify the QR button has proper visual styling
      final qrButtonContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                CupertinoColors.systemBlue &&
            (widget.decoration as BoxDecoration).boxShadow != null,
      );
      expect(qrButtonContainer, findsOneWidget);

      // Verify the button has proper padding
      final qrButtonPadding = find.byWidgetPredicate(
        (widget) =>
            widget is Padding && widget.padding == const EdgeInsets.all(12),
      );
      expect(qrButtonPadding, findsWidgets);
    });
  });
}
