import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/sensitive_session_controller.dart';
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
    final SensitiveSessionController session = SensitiveSessionController(
      history,
    );

    await session.clear();

    expect(session.revision, 1);
    expect(history.entries, isEmpty);
    expect(prefs.getString(CanvasController.currentKey), isNull);
    final String savedLayouts = prefs.getString(CanvasController.layoutsKey)!;
    expect(savedLayouts, isNot(contains(raw)));
    expect(savedLayouts, isNot(contains(encoded)));
    expect((jsonDecode(savedLayouts) as Map<String, dynamic>).keys, <String>[
      'Safe layout',
    ]);
  });
}
