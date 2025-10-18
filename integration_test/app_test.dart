import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:masquerade/main.dart' as app;

/// Integration tests for the Flutter app
/// This file should trigger testing-specific Flutter rules
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('should complete user registration flow', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to registration page
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Fill registration form
      await tester.enterText(find.byKey(const Key('name_field')), 'John Doe');
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'john@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify success
      expect(find.text('Registration successful'), findsOneWidget);
      expect(find.text('Welcome, John Doe'), findsOneWidget);
    });

    testWidgets('should handle login flow', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login page
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Fill login form
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'john@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify success
      expect(find.text('Welcome back, John'), findsOneWidget);
    });

    testWidgets('should handle error scenarios', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login page
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Fill login form with invalid credentials
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'invalid@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'wrongpassword',
      );

      // Submit form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify error message
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('should handle responsive design', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test mobile viewport
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await tester.pumpAndSettle();

      // Verify mobile layout
      expect(find.byKey(const Key('mobile_navigation')), findsOneWidget);

      // Test tablet viewport
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpAndSettle();

      // Verify tablet layout
      expect(find.byKey(const Key('tablet_navigation')), findsOneWidget);

      // Test desktop viewport
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pumpAndSettle();

      // Verify desktop layout
      expect(find.byKey(const Key('desktop_navigation')), findsOneWidget);
    });

    testWidgets('should handle navigation flow', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to different pages
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home Page'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Page'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings Page'), findsOneWidget);
    });

    testWidgets('should handle form validation', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to registration page
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Try to submit empty form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify validation errors
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Fill form with invalid data
      await tester.enterText(find.byKey(const Key('name_field')), '');
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'invalid-email',
      );
      await tester.enterText(find.byKey(const Key('password_field')), '123');

      // Submit form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify validation errors
      expect(find.text('Name cannot be empty'), findsOneWidget);
      expect(find.text('Invalid email format'), findsOneWidget);
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('should handle loading states', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login page
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Fill login form
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'john@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit form
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pump();

      // Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();

      // Verify success
      expect(find.text('Welcome back, John'), findsOneWidget);
    });
  });

  group('Platform-Specific Tests', () {
    testWidgets('should work on different screen sizes', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test various screen sizes
      final screenSizes = [
        const Size(320, 568), // iPhone SE
        const Size(375, 667), // iPhone 8
        const Size(414, 896), // iPhone 11
        const Size(768, 1024), // iPad
        const Size(1024, 768), // iPad landscape
        const Size(1920, 1080), // Desktop
      ];

      for (final size in screenSizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();

        // Verify app still works
        expect(find.text('Welcome'), findsOneWidget);
      }
    });

    testWidgets('should handle keyboard navigation', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test tab navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Verify focus
      expect(find.byKey(const Key('focused_element')), findsOneWidget);
    });
  });
}
