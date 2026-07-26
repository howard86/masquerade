import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/share_inbox_controller.dart';
import 'package:masquerade/state/sensitive_session_controller.dart';
import 'package:masquerade/state/tool_draft_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clear removes current state and scrubs legacy saved layouts', () async {
    const String raw = 'raw-credential-fixture';
    const String encoded =
        'eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsLWZpeHR1cmUifQ==';
    final Map<String, dynamic> snapshot = <String, dynamic>{
      'cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'tool': 'base64',
          'x': 0,
          'y': 0,
          'w': 380,
          'seed': encoded,
        },
      ],
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      CanvasController.currentKey: jsonEncode(snapshot),
      CanvasController.layoutsKey: jsonEncode(<String, dynamic>{
        'Safe layout': snapshot,
        'password=$raw': snapshot,
      }),
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController history = HistoryController(prefs: prefs);
    await history.add(
      HistoryEntry(
        utilityId: 'timestamp',
        input: '1717171717',
        output: 'safe',
        timestamp: DateTime.now(),
      ),
    );
    final WorkSessionController workSession = WorkSessionController()
      ..start(
        UtilityCatalog.byId('jwt'),
        Artifact<Object?>(
          kind: ArtifactKind.jwt,
          rawValue: encoded,
          provenance: ArtifactProvenance.clipboard,
        ),
      );
    final ToolDraftController toolDrafts = await ToolDraftController.load();
    const MethodChannel inboxChannel = MethodChannel('test/share-inbox-clear');
    final List<String> inboxCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inboxChannel, (MethodCall call) async {
          inboxCalls.add(call.method);
          return call.method == 'list' ? <Object?>[] : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(inboxChannel, null),
    );
    final ShareInboxController shareInbox = await ShareInboxController.load(
      channel: inboxChannel,
    );
    await toolDrafts.saveJson(
      input: '{"safe":true}',
      source: 'json',
      target: 'prettyJson',
    );
    final SensitiveSessionController session = SensitiveSessionController(
      history,
      workSession: workSession,
      toolDrafts: toolDrafts,
      shareInbox: shareInbox,
    );

    await session.clear();

    expect(session.revision, 1);
    expect(history.entries, isEmpty);
    expect(workSession.session, isNull);
    expect(toolDrafts.json, isNull);
    expect(inboxCalls, contains('clear'));
    expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);
    await toolDrafts.saveJson(
      input: '{"new":true}',
      source: 'json',
      target: 'prettyJson',
    );
    expect(toolDrafts.json!.input, '{"new":true}');
    expect(prefs.getString(CanvasController.currentKey), isNull);
    final String savedLayouts = prefs.getString(CanvasController.layoutsKey)!;
    expect(savedLayouts, isNot(contains(raw)));
    expect(savedLayouts, isNot(contains(encoded)));
    expect((jsonDecode(savedLayouts) as Map<String, dynamic>).keys, <String>[
      'Safe layout',
    ]);
  });
}
