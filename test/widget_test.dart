import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/app.dart';

void main() {
  testWidgets('Masquerade app test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify the app title is displayed
    expect(find.text('Masquerade'), findsOneWidget);

    // Verify SafeArea is present
    expect(find.byType(SafeArea), findsOneWidget);

    // Find the input field by its placeholder text.
    final inputField = find.byWidgetPredicate(
      (widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Enter Unix timestamp or ISO 8601 date',
    );
    expect(inputField, findsOneWidget);

    // Test with a valid Unix timestamp (seconds).
    await tester.enterText(inputField, '1700000000');
    await tester.pumpAndSettle();

    // Should display the TimestampDisplayCard
    expect(find.text('Conversion Results'), findsOneWidget);
    expect(find.text('UTC Time:'), findsOneWidget);
    expect(find.text('Local Time:'), findsOneWidget);
    expect(find.text('Unix Timestamp (seconds):'), findsOneWidget);
    expect(find.text('Unix Timestamp (milliseconds):'), findsOneWidget);

    // Test with a valid Unix timestamp (milliseconds).
    await tester.enterText(inputField, '1700000000000');
    await tester.pumpAndSettle();

    // Should still display the TimestampDisplayCard
    expect(find.text('Conversion Results'), findsOneWidget);

    // Test with an invalid string.
    await tester.enterText(inputField, 'not a timestamp');
    await tester.pumpAndSettle();

    // Should display an error message.
    expect(find.textContaining('Invalid timestamp format'), findsOneWidget);

    // Clear the input.
    await tester.enterText(inputField, '');
    await tester.pumpAndSettle();

    // Should not display the timestamp card or error message.
    expect(find.text('Timestamp Conversion'), findsNothing);
    expect(find.textContaining('Invalid timestamp format'), findsNothing);
  });

  testWidgets('TimestampDisplayCard copy functionality test', (
    WidgetTester tester,
  ) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Enter a valid timestamp
    final inputField = find.byWidgetPredicate(
      (widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Enter Unix timestamp or ISO 8601 date',
    );
    await tester.enterText(inputField, '1700000000');
    await tester.pumpAndSettle();

    // Find a copyable timestamp value and tap it
    final copyableValue = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.child is Container &&
          (widget.child as Container).child is Row,
    );
    expect(copyableValue, findsWidgets);

    // Tap on the first copyable value
    await tester.tap(copyableValue.first);
    await tester.pumpAndSettle();

    // Should show a notification with copy confirmation
    expect(find.text('Copied to clipboard'), findsOneWidget);
    expect(find.textContaining('Copied to clipboard'), findsOneWidget);

    // Wait for the auto-dismiss timer and pump
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
