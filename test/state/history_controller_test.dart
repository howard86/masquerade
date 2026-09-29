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

  group('HistoryController.search', () {
    test('matches a naive lowercase scan over every field', () async {
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      final DateTime ts = DateTime(2026, 7, 18, 10, 30);
      final List<HistoryEntry> seed = <HistoryEntry>[
        HistoryEntry(
          utilityId: 'json',
          input: '{"Hello":"World"}',
          output: 'PRETTY',
          timestamp: ts,
        ),
        HistoryEntry(
          utilityId: 'base64',
          input: 'b3JkaW5hcnk=',
          output: 'Ordinary',
          timestamp: ts.add(const Duration(minutes: 1)),
        ),
        HistoryEntry(
          utilityId: 'case',
          input: 'snake_case',
          output: 'SnakeCase',
          timestamp: ts.add(const Duration(minutes: 2)),
        ),
      ];
      for (final HistoryEntry e in seed) {
        await c.add(e);
      }
      String tool(HistoryEntry e) => 'Tool ${e.utilityId.toUpperCase()}';
      String date(HistoryEntry e) => 'Saturday July ${e.timestamp.minute}';
      List<HistoryEntry> naive(String query) {
        final String q = query.trim().toLowerCase();
        if (q.isEmpty) return c.entries.toList();
        return c.entries.where((HistoryEntry e) {
          return <String>[
            e.utilityId,
            tool(e),
            e.timestamp.toIso8601String(),
            date(e),
            if (!e.protected) ...<String>[e.input, e.output],
          ].any((String v) => v.toLowerCase().contains(q));
        }).toList();
      }

      for (final String q in <String>[
        '',
        '  ',
        'hello',
        'WORLD',
        'pretty',
        'ordinary',
        'tool case',
        'july 1',
        '2026-07-18',
        'snakecase',
        'nothing-matches',
      ]) {
        expect(
          c.search(q, toolName: tool, dateLabel: date),
          naive(q),
          reason: q,
        );
      }
    });

    test('entries is a read-only view', () async {
      final HistoryController c = HistoryController(retention: Duration.zero);
      await c.add(entry('json', '{}'));
      expect(() => c.entries.add(entry('json', '[]')), throwsUnsupportedError);
      expect(() => c.entries.clear(), throwsUnsupportedError);
    });
  });
}
