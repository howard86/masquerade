import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utils/shell_layout.dart';

void main() {
  group('desktopShellSupported', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('supports native macOS without a web override', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(desktopShellSupported(), isTrue);
    });

    test('keeps native mobile platforms on the mobile shell', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(desktopShellSupported(), isFalse);
    });

    test('explicit override remains deterministic for widget tests', () {
      expect(desktopShellSupported(override: true), isTrue);
      expect(desktopShellSupported(override: false), isFalse);
    });
  });

  group('resolveShellLayout', () {
    test('supported wide surface + desktop mode → desktop', () {
      expect(
        resolveShellLayout(
          desktopSupported: true,
          width: 1200,
          height: 900,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.desktop,
      );
    });

    test('supported wide surface + mobile mode → framedMobile', () {
      expect(
        resolveShellLayout(
          desktopSupported: true,
          width: 1200,
          height: 900,
          viewMode: MqViewMode.mobile,
        ),
        MqShellLayout.framedMobile,
      );
    });

    test('unsupported wide viewport → framedMobile', () {
      expect(
        resolveShellLayout(
          desktopSupported: false,
          width: 1200,
          height: 1000,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.framedMobile,
      );
    });

    test('supported surface below the breakpoint → framedMobile', () {
      expect(
        resolveShellLayout(
          desktopSupported: true,
          width: 800,
          height: 1000,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.framedMobile,
      );
    });

    test('phone-sized viewport → bareMobile', () {
      expect(
        resolveShellLayout(
          desktopSupported: true,
          width: 393,
          height: 852,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.bareMobile,
      );
    });
  });

  group('toggleAvailable', () {
    test('true only on a supported wide surface', () {
      expect(toggleAvailable(desktopSupported: true, width: 1200), isTrue);
      expect(toggleAvailable(desktopSupported: true, width: 900), isTrue);
    });

    test('false below the breakpoint or on an unsupported surface', () {
      expect(toggleAvailable(desktopSupported: true, width: 899), isFalse);
      expect(toggleAvailable(desktopSupported: false, width: 1600), isFalse);
    });
  });
}
