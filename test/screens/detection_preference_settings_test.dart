import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Settings resets saved detection choices', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DetectionPreferenceController preferences =
        DetectionPreferenceController();
    await preferences.prefer(
      UtilityCatalog.detectArtifacts('1700000000'),
      ArtifactKind.number,
    );
    await tester.pumpWidget(
      MyApp(
        isWebOverride: false,
        skipSplash: true,
        detectionPreferenceController: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Open Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your type-only detection choices are active.'),
      findsOneWidget,
    );
    final Finder reset = find.text('Reset detection choices');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    expect(find.text('No detection choices have been saved.'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(DetectionPreferenceController.storageKey),
      isFalse,
    );
    expect(
      preferences
          .rank(UtilityCatalog.detectArtifacts('1700000000'))
          .first
          .artifact
          .kind,
      ArtifactKind.timestamp,
    );
  });
}
