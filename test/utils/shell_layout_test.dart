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

    test('native wide viewport → tablet (was the framed-bezel bug)', () {
      // ADR-0004: a native large screen used to fall to framedMobile — the
      // fake iPhone bezel on a real iPad. It now resolves to the tablet shell.
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 1200,
          height: 1000,
          viewMode: MqViewMode.desktop,
        ),
        MqShellLayout.tablet,
      );
    });

    test('native iPad portrait → tablet', () {
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 768,
          height: 1024,
          viewMode: MqViewMode.mobile,
        ),
        MqShellLayout.tablet,
      );
    });

    test('native iPad landscape → tablet', () {
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 1024,
          height: 768,
          viewMode: MqViewMode.mobile,
        ),
        MqShellLayout.tablet,
      );
    });

    test('native phone landscape → not tablet (short-side gate)', () {
      // iPhone 16 Pro Max landscape (932×430): wide but short. The both-
      // dimension gate keeps a phone out of the split-view shell.
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 932,
          height: 430,
          viewMode: MqViewMode.mobile,
        ),
        isNot(MqShellLayout.tablet),
      );
    });

    test('iPad Split-View slim window → not tablet (width gate)', () {
      // A slim multitasking window (~375 wide, full height) is too narrow for
      // the split view; it stays on the phone presentation.
      expect(
        resolveShellLayout(
          isWeb: false,
          width: 375,
          height: 1180,
          viewMode: MqViewMode.mobile,
        ),
        isNot(MqShellLayout.tablet),
      );
    });

    test('web wide viewport is never tablet (preview path preserved)', () {
      // The tablet shell is `!isWeb`-gated, so a wide browser window still
      // previews the mobile UI in the silhouette (framedMobile).
      expect(
        resolveShellLayout(
          isWeb: true,
          width: 1200,
          height: 1000,
          viewMode: MqViewMode.mobile,
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
