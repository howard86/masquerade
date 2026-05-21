import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utils/shell_layout.dart';

void main() {
  group('resolveShellLayout', () {
    test('wide web + desktop mode → desktop', () {
      expect(
        resolveShellLayout(
          isWeb: true,
          width: 1200,
          height: 900,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.desktop,
      );
    });

    test('wide web + mobile mode → framedMobile (never desktop)', () {
      expect(
        resolveShellLayout(
          isWeb: true,
          width: 1200,
          height: 900,
          viewMode: MqViewMode.mobile,
        ),
        MqShellLayout.framedMobile,
      );
    });

    test('non-web wide viewport → framedMobile even in desktop mode', () {
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 1200,
          height: 1000,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.framedMobile,
      );
    });

    test('web below the breakpoint → framedMobile, not desktop', () {
      expect(
        resolveShellLayout(
          isWeb: true,
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
          isWeb: true,
          width: 393,
          height: 852,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.bareMobile,
      );
    });
  });

  group('toggleAvailable', () {
    test('true only on wide web', () {
      expect(toggleAvailable(isWeb: true, width: 1200), isTrue);
      expect(toggleAvailable(isWeb: true, width: 900), isTrue);
    });

    test('false below the breakpoint or off the web', () {
      expect(toggleAvailable(isWeb: true, width: 899), isFalse);
      expect(toggleAvailable(isWeb: false, width: 1600), isFalse);
    });
  });
}
