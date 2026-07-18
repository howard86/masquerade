import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  List<DetectionMatch<Object?>> detect(String input) =>
      UtilityCatalog.detectArtifacts(input);

  test('persists and reloads only the ten-digit ambiguity class', () async {
    final DetectionPreferenceController controller =
        DetectionPreferenceController();
    final List<DetectionMatch<Object?>> matches = detect('  1700000000  ');
    final DetectionMatch<Object?> number = matches.singleWhere(
      (match) => match.artifact.kind == ArtifactKind.number,
    );

    await controller.prefer(matches, ArtifactKind.number);

    final List<DetectionMatch<Object?>> ranked = controller.rank(matches);
    expect(ranked.first, same(number));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), <String>{DetectionPreferenceController.storageKey});
    expect(
      prefs.getStringList(DetectionPreferenceController.storageKey),
      <String>['ten_digit_integer=number'],
    );
    expect(
      prefs.getStringList(DetectionPreferenceController.storageKey)!.join('|'),
      isNot(contains('1700000000')),
    );

    final DetectionPreferenceController reloaded =
        await DetectionPreferenceController.load();
    expect(
      reloaded.rank(detect('1700000001')).first.artifact.kind,
      ArtifactKind.number,
    );
  });

  test('ten-digit preference does not affect other ambiguity shapes', () async {
    final DetectionPreferenceController controller =
        DetectionPreferenceController();
    await controller.prefer(detect('1700000000'), ArtifactKind.number);

    final List<DetectionMatch<Object?>> thirteenDigits = detect(
      '1700000000000',
    );
    expect(controller.canPrefer(thirteenDigits), isFalse);
    expect(controller.rank(thirteenDigits).first, same(thirteenDigits.first));

    final List<DetectionMatch<Object?>> jwt = detect(
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature',
    );
    expect(controller.canPrefer(jwt), isFalse);
    expect(controller.rank(jwt).first, same(jwt.first));
  });

  test('ignores malformed entries and reset removes their storage', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DetectionPreferenceController.storageKey: <String>[
        'number|timestamp=number',
        'ten_digit_integer=jwt',
        'raw-secret-value',
      ],
    });
    final DetectionPreferenceController controller =
        await DetectionPreferenceController.load();
    expect(controller.hasPreferences, isFalse);

    await controller.reset();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(DetectionPreferenceController.storageKey),
      isFalse,
    );
  });

  test('reset restores default ranking', () async {
    final DetectionPreferenceController controller =
        DetectionPreferenceController();
    final List<DetectionMatch<Object?>> matches = detect('1700000000');
    await controller.prefer(matches, ArtifactKind.number);
    expect(controller.rank(matches).first.artifact.kind, ArtifactKind.number);

    await controller.reset();

    expect(
      controller.rank(matches).first.artifact.kind,
      ArtifactKind.timestamp,
    );
  });
}
