import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/tool_bodies/artifact_inspector_body.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';

import '_helpers.dart';

void main() {
  testWidgets(
    'renders bounded tree, evidence, confidence, and security warning',
    (WidgetTester tester) async {
      final String token = _jwt(<String, Object?>{'exp': 1700000000});

      await pumpBodyAtWidth(
        tester,
        ArtifactInspectorBody(initialInput: token),
        340,
      );

      expect(find.text('JWT'), findsOneWidget);
      expect(find.textContaining('CONFIDENCE'), findsWidgets);
      expect(find.text('SENSITIVE CONTENT HIDDEN.'), findsOneWidget);
      expect(find.text('••••'), findsWidgets);
    },
  );

  testWidgets('sensitive standalone descendants never use untyped routing', (
    WidgetTester tester,
  ) async {
    final String token = _jwt(<String, Object?>{'exp': 1700000000});
    int calls = 0;

    await pumpBodyAtWidth(
      tester,
      ArtifactInspectorBody(
        initialInput: token,
        onSwitchTool: (_, _) => calls++,
      ),
      340,
    );

    expect(find.text('Open in Timestamp'), findsNothing);
    expect(find.text('Extract layer'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('protected session can add a sensitive descendant as next step', (
    WidgetTester tester,
  ) async {
    final String token = _jwt(<String, Object?>{'exp': 1700000000});
    String? routed;

    await pumpBodyAtWidth(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: true,
        child: ArtifactInspectorBody(
          initialInput: token,
          initialArtifact: Artifact<Object?>(
            kind: ArtifactKind.jwt,
            rawValue: token,
            provenance: ArtifactProvenance.generated,
            sensitivity: ArtifactSensitivity.sensitive,
          ),
          onSwitchTool: (_, String value) => routed = value,
        ),
      ),
      340,
    );

    final Finder action = find.text('Add next step Timestamp');
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(routed, '1700000000');
  });

  testWidgets('standard layers can be extracted', (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final String json = '{"ok":true}';

    await pumpBodyAtWidth(
      tester,
      ArtifactInspectorBody(initialInput: base64Encode(utf8.encode(json))),
      340,
    );
    final Finder extract = find.widgetWithText(MqButton, 'Extract layer').first;
    await tester.ensureVisible(extract);
    await tester.tap(extract);

    expect(copied, base64Encode(utf8.encode(json)));
  });

  testWidgets('remains usable at 2x text scale', (WidgetTester tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await pumpBodyAtWidth(
      tester,
      ArtifactInspectorBody(
        initialInput: base64Encode(utf8.encode('{"value":1700000000}')),
      ),
      340,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('UTF-8 text'), findsOneWidget);
  });

  testWidgets('catalog route opens Artifact Inspector', (
    WidgetTester tester,
  ) async {
    expect(
      UtilityCatalog.byId('artifact_inspector').historyPolicy,
      HistoryPolicy.disabled,
    );
    await pumpHomeAndOpen(tester, 'Artifact Inspector');
    expect(find.byType(ArtifactInspectorBody), findsOneWidget);
  });
}

String _jwt(Map<String, Object?> payload) {
  String segment(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment(<String, String>{'alg': 'none'})}.${segment(payload)}.';
}
