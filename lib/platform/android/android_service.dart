import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'dart:io';

/// Android service that handles Android-specific functionality
/// This file should trigger Android-specific Flutter rules
class AndroidService {
  static String getPlatformName() {
    return 'Android';
  }

  /// Handles Android-specific features like Material Design, etc.
  static void handleAndroidSpecificFeature() {
    if (Platform.isAndroid) {
      // Android-specific implementation
      _enableMaterialDesign();
      _setupAndroidNavigation();
      _handleAndroidPermissions();
    }
  }

  /// Enables Material Design components
  static void _enableMaterialDesign() {
    // Material Design implementation
    developer.log('Enabling Material Design...');
  }

  /// Sets up Android-specific navigation patterns
  static void _setupAndroidNavigation() {
    // Android navigation implementation
    developer.log('Setting up Android navigation...');
  }

  /// Handles Android-specific permissions
  static void _handleAndroidPermissions() {
    // Android permissions implementation
    developer.log('Handling Android permissions...');
  }

  /// Android-specific UI components
  static Widget createAndroidButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(onPressed: onPressed, child: Text(text));
  }

  /// Android-specific haptic feedback
  static void triggerHapticFeedback() {
    HapticFeedback.vibrate();
  }

  /// Android-specific status bar handling
  static void setAndroidStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  /// Android-specific back button handling
  static void handleAndroidBackButton(BuildContext context) {
    SystemNavigator.pop();
  }
}
