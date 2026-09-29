import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  HistoryEntry entry(
    String utilityId,
    String input, {
    String output = 'out',
    bool sensitive = false,
  }) => HistoryEntry(
    utilityId: utilityId,
    input: input,
    output: output,
    timestamp: DateTime.now(),
    sensitive: sensitive,
  );

  bool rescan(HistoryEntry e) => SensitiveDataPolicy.protects(
    utilityId: e.utilityId,
    sensitive: e.sensitive,
    values: <String>[e.input, e.output],
  );

  List<HistoryEntry> mixed() => <HistoryEntry>[
    entry('json', '{"plain":true}'),
    entry('json', 'CLIENT_SECRET=fixture'),
    entry('json', '{"ok":1}', output: 'password: hunter2'),
    entry('base64', base64.encode(utf8.encode('API_KEY=abc'))),
    entry('base64', 'aGVsbG8='),
    entry('url', 'token%3Dabc'),
    entry('case', 'hello world', sensitive: true),
    entry('jwt', 'a.b.c'),
    entry('hash', 'ordinary text'),
  ];

  group('HistoryEntry.protected cache', () {
    test('matches a fresh policy scan for every shape', () {
      for (final HistoryEntry e in mixed()) {
        expect(e.protected, rescan(e), reason: '${e.utilityId}:${e.input}');
        expect(e.protected, rescan(e), reason: 'second read is stable');
      }
    });

    test('toJson redaction follows the cached flag', () {
      final HistoryEntry secret = entry('json', 'CLIENT_SECRET=fixture');
      final Map<String, dynamic> json = secret.toJson();
      expect(json['input'], '');
      expect(json['output'], '');
      expect(json['sensitive'], isTrue);
    });
  });

  group('HistoryController invariant: no protected entry is stored', () {
    test('via add', () async {
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      for (final HistoryEntry e in mixed()) {
        await c.add(e);
      }
      expect(c.entries, isNotEmpty);
      for (final HistoryEntry e in c.entries) {
        expect(e.protected, isFalse);
        expect(rescan(e), isFalse);
      }
    });

    test('via load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(<Map<String, dynamic>>[
          for (final HistoryEntry e in mixed())
            <String, dynamic>{
              'utilityId': e.utilityId,
              'input': e.input,
              'output': e.output,
              'ts': DateTime.now().millisecondsSinceEpoch,
              'sensitive': e.sensitive,
            },
        ]),
      });
      final HistoryController c = await HistoryController.load();
      expect(c.entries, isNotEmpty);
      for (final HistoryEntry e in c.entries) {
        expect(e.protected, isFalse);
        expect(rescan(e), isFalse);
      }
    });
  });
}
