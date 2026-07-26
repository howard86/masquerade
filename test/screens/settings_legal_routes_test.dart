import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/main.dart' show registerBundledFontLicenses;
import 'package:masquerade/screens/acknowledgements_screen.dart';
import 'package:masquerade/screens/privacy_policy_screen.dart';
import 'package:masquerade/screens/settings_screen.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/theme_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';

Widget _host({
  Widget home = const SettingsScreen(desktopShellOverride: false),
}) {
  return CupertinoApp(
    builder: (BuildContext context, Widget? child) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: ThemeScope(
        controller: ThemeController(),
        child: DetectionPreferenceScope(
          controller: DetectionPreferenceController(),
          child: HistoryScope(
            controller: HistoryController(),
            child: ViewModeScope(
              controller: ViewModeController(),
              child: WallpaperScope(
                controller: WallpaperController(),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ),
    home: home,
  );
}

void main() {
  test('registers the bundled license for every IBM Plex family', () async {
    LicenseRegistry.reset();
    registerBundledFontLicenses();

    final List<LicenseEntry> licenses = await LicenseRegistry.licenses.toList();

    expect(licenses, hasLength(1));
    expect(
      licenses.single.packages,
      containsAll(<String>['IBM Plex Mono', 'IBM Plex Sans', 'IBM Plex Serif']),
    );
    expect(
      licenses.single.paragraphs.map((LicenseParagraph p) => p.text).join(),
      contains('SIL OPEN FONT LICENSE'),
    );
  });

  testWidgets(
    'Settings opens the bundled privacy policy and acknowledgements',
    (WidgetTester tester) async {
      LicenseRegistry.reset();
      registerBundledFontLicenses();
      await tester.binding.setSurfaceSize(const Size(480, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Privacy Policy'), 200);
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.textContaining('does not collect, store'), findsOneWidget);

      Navigator.of(tester.element(find.byType(PrivacyPolicyScreen))).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Acknowledgements'), 200);
      await tester.tap(find.text('Acknowledgements'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AcknowledgementsScreen), findsOneWidget);
      expect(find.text('Acknowledgements'), findsOneWidget);
    },
  );

  testWidgets('Acknowledgements reports a license collector failure', (
    WidgetTester tester,
  ) async {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(
      () => Stream<LicenseEntry>.error(StateError('license failed')),
    );

    await tester.pumpWidget(_host(home: const AcknowledgementsScreen()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Acknowledgements could not be loaded.'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });
}
