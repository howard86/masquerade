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
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      await c.add(entry('json', '{}'));
      expect(() => c.entries.add(entry('json', '[]')), throwsUnsupportedError);
      expect(() => c.entries.clear(), throwsUnsupportedError);
    });
  });

  group('HistoryController size cap', () {
    test('skips new entries with oversized input or output', () async {
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      final String atInput = 'a' * HistoryController.maxInputLength;
      final String atOutput = 'b' * HistoryController.maxOutputLength;
      await c.add(entry('json', atInput, output: atOutput));
      await c.add(entry('json', '${atInput}x'));
      await c.add(entry('json', 'small', output: '${atOutput}y'));
      expect(c.entries, hasLength(1));
      expect(c.entries.single.input, atInput);
      expect(c.entries.single.output, atOutput);
    });

    test('keeps oversized entries already persisted', () async {
      final String big = 'c' * (HistoryController.maxInputLength + 1);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'utilityId': 'json',
            'input': big,
            'output': 'out',
            'ts': DateTime.now().millisecondsSinceEpoch,
            'id': 'legacy',
          },
        ]),
      });
      final HistoryController c = await HistoryController.load();
      expect(c.entries.single.input, big);
    });
  });

  group('HistoryController persistence', () {
    HistoryEntry sized(String id, int chars, {bool pinned = false}) =>
        HistoryEntry(
          utilityId: 'json',
          input: 'in $id',
          output: 'o' * chars,
          timestamp: DateTime.now(),
          pinned: pinned,
          id: id,
        );

    Future<List<dynamic>> stored() async =>
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                'mb.history.entries',
              )!,
            )
            as List<dynamic>;

    test('writes are debounced and flush writes immediately', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final HistoryController c = HistoryController(
        prefs: prefs,
        retention: const Duration(days: 36500),
        persistDelay: const Duration(milliseconds: 500),
      );
      await c.add(entry('json', '{"a":1}'));
      await c.add(entry('json', '{"b":2}'));
      expect(prefs.getString('mb.history.entries'), isNull);
      await c.flush();
      expect(await stored(), hasLength(2));
    });

    test('the debounce timer writes without a flush', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final HistoryController c = HistoryController(
        prefs: prefs,
        retention: const Duration(days: 36500),
        persistDelay: const Duration(milliseconds: 10),
      );
      await c.add(entry('json', '{"a":1}'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await stored(), hasLength(1));
    });

    test('delete and clear write immediately', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final HistoryController c = HistoryController(
        prefs: prefs,
        retention: const Duration(days: 36500),
        persistDelay: const Duration(milliseconds: 500),
      );
      final HistoryEntry a = entry('json', '{"a":1}');
      await c.add(a);
      await c.add(entry('json', '{"b":2}'));
      await c.delete(c.entries.last);
      expect(await stored(), hasLength(1));
      await c.clear();
      expect(await stored(), isEmpty);
    });

    test(
      'persisted copy stays within the budget, oldest unpinned first',
      () async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final HistoryController c = HistoryController(
          prefs: prefs,
          retention: const Duration(days: 36500),
          maxPersistedChars: 1000,
        );
        // Oldest first so the list ends newest-first: n4 n3 n2 n1 old-pinned.
        await c.add(sized('old-pinned', 200, pinned: true));
        for (int i = 1; i <= 4; i++) {
          await c.add(sized('n$i', 200));
        }
        await c.flush();
        final String raw = prefs.getString('mb.history.entries')!;
        expect(raw.length, lessThanOrEqualTo(1000));
        final List<String> ids = (jsonDecode(raw) as List<dynamic>)
            .map((dynamic e) => (e as Map<String, dynamic>)['id'] as String)
            .toList();
        expect(ids, <String>['n4', 'n3', 'old-pinned']);
        // Memory keeps everything; only the persisted copy is trimmed.
        expect(c.entries, hasLength(5));
      },
    );

    test('pinned entries go last when the budget cannot fit them', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final HistoryController c = HistoryController(
        prefs: prefs,
        retention: const Duration(days: 36500),
        maxPersistedChars: 600,
      );
      await c.add(sized('p1', 300, pinned: true));
      await c.add(sized('p2', 300, pinned: true));
      await c.flush();
      final List<dynamic> list = await stored();
      expect(list, hasLength(1));
      expect((list.single as Map<String, dynamic>)['id'], 'p2');
    });

    test('a failing write is swallowed and retried smaller', () async {
      final _QuotaPrefs prefs = _QuotaPrefs(quota: 60000);
      final HistoryController c = HistoryController(
        prefs: prefs,
        retention: const Duration(days: 36500),
      );
      for (int i = 0; i < 4; i++) {
        await c.add(sized('e$i', 30000));
      }
      await c.flush();
      expect(prefs.written, isNotNull);
      expect(prefs.written!.length, lessThanOrEqualTo(60000));

      final _QuotaPrefs dead = _QuotaPrefs(quota: 0);
      final HistoryController d = HistoryController(
        prefs: dead,
        retention: const Duration(days: 36500),
      );
      await d.add(sized('x', 10));
      await d.flush();
      expect(dead.written, isNull);
      expect(d.entries, hasLength(1));
    });

    test('load skips the rescan for the current policy version', () async {
      final Map<String, dynamic> secret = <String, dynamic>{
        'utilityId': 'json',
        'input': '{"password":"hunter2hunter2"}',
        'output': 'out',
        'ts': DateTime.now().millisecondsSinceEpoch,
        'id': 'a',
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(<Map<String, dynamic>>[secret]),
      });
      // No stored version: rescan drops it and records the version.
      final HistoryController stale = await HistoryController.load();
      expect(stale.entries, isEmpty);
      await stale.flush();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('mb.history.policy.version'), isNotNull);

      // Stored by the current version: trusted as already clean.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(<Map<String, dynamic>>[secret]),
        'mb.history.policy.version': HistoryController.policyVersion,
      });
      final HistoryController current = await HistoryController.load();
      expect(current.entries, hasLength(1));
      await current.flush();
      expect(
        ((await stored()).single as Map<String, dynamic>)['input'],
        secret['input'],
      );
    });

    test('load persists migrations without blocking, then flushes', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'utilityId': 'json',
            'input': '{}',
            'output': '{}',
            'ts': DateTime.now().millisecondsSinceEpoch,
          },
        ]),
        'mb.history.policy.version': HistoryController.policyVersion,
      });
      final HistoryController c = await HistoryController.load();
      await c.flush();
      expect(
        ((await stored()).single as Map<String, dynamic>)['id'],
        isNotNull,
      );
    });

    test('entries is a stable view until a mutation', () async {
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      expect(identical(c.entries, c.entries), isTrue);
      final List<HistoryEntry> before = c.entries;
      await c.add(entry('json', '{"a":1}'));
      expect(identical(before, c.entries), isFalse);
      expect(before, isEmpty);
      final List<HistoryEntry> afterAdd = c.entries;
      expect(identical(afterAdd, c.entries), isTrue);
      expect(() => c.entries.add(entry('json', 'x')), throwsUnsupportedError);
      await c.togglePinned(c.entries.single);
      expect(identical(afterAdd, c.entries), isFalse);
    });

    test('search sees updated entries after a mutation', () async {
      final HistoryController c = HistoryController(
        retention: const Duration(days: 36500),
      );
      await c.add(entry('json', '{"Alpha":1}'));
      expect(c.search('alpha'), hasLength(1));
      await c.add(entry('json', '{"Beta":1}'));
      expect(c.search('beta'), hasLength(1));
      expect(c.search('alpha'), hasLength(1));
    });
  });
}

/// A SharedPreferences stand-in whose `setString` throws past [quota] chars,
/// like a full web localStorage.
class _QuotaPrefs implements SharedPreferences {
  _QuotaPrefs({required this.quota});

  final int quota;
  String? written;

  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  Future<bool> setString(String key, String value) async {
    if (value.length > quota) throw StateError('QuotaExceededError');
    written = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
