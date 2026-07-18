import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  HistoryEntry entry(
    String utilityId,
    String input, {
    String? output,
    bool sensitive = false,
  }) => HistoryEntry(
    utilityId: utilityId,
    input: input,
    output: output ?? input.toUpperCase(),
    timestamp: DateTime.now(),
    sensitive: sensitive,
  );

  group('HistoryController.add dedupe', () {
    test('skips when most recent entry has same utilityId and input', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello'));
      await c.add(entry('base64', 'hello'));
      expect(c.entries.length, 1);
      expect(c.entries.first.input, 'hello');
    });

    test('only the most recent is checked — A, B, A keeps all three', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'a'));
      await c.add(entry('base64', 'b'));
      await c.add(entry('base64', 'a'));
      expect(c.entries.length, 3);
      expect(c.entries[0].input, 'a');
      expect(c.entries[1].input, 'b');
      expect(c.entries[2].input, 'a');
    });

    test('different utilityId with same input does not dedupe', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello'));
      await c.add(entry('json', 'hello'));
      expect(c.entries.length, 2);
      expect(c.entries.first.utilityId, 'json');
    });

    test('output is not part of the dedupe key', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello', output: 'aGVsbG8='));
      await c.add(entry('base64', 'hello', output: 'different'));
      expect(c.entries.length, 1);
    });
  });

  group('HistoryController policy', () {
    test('serialization redacts raw credential fixtures', () {
      final Map<String, dynamic> json = entry(
        'json',
        '{"password":"raw-credential-fixture"}',
      ).toJson();
      final String serialized = jsonEncode(json);

      expect(serialized, isNot(contains('raw-credential-fixture')));
      expect(json['sensitive'], isTrue);
      expect(json['input'], isEmpty);
    });

    test(
      'disables JWT and Generator while normal tools still record',
      () async {
        final HistoryController c = HistoryController();

        await c.add(entry('jwt', 'header.payload.signature'));
        await c.add(entry('generator', 'password config'));
        await c.add(entry('timestamp', '1717171717'));
        await c.add(entry('color', '#336699'));
        await c.add(entry('number_base', '0xff'));

        expect(c.entries.map((HistoryEntry e) => e.utilityId), <String>[
          'number_base',
          'color',
          'timestamp',
        ]);
      },
    );

    test(
      'rejects credential, private-key, env, and authorization shapes',
      () async {
        final HistoryController c = HistoryController();
        final List<String> sensitive = <String>[
          '{"password":"not-a-real-secret"}',
          '{"access_token":"fixture"}',
          '{"AWS_SECRET_ACCESS_KEY":"fixture"}',
          '{"x-api-key":"fixture"}',
          '\n  session_token: fixture',
          'database.password: fixture',
          '- refresh_token: fixture',
          '{"token":"fixture"}',
          'secret_access_key: fixture',
          '-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----',
          'DEBUG=true',
          'DEBUG = true',
          'feature_flag=true',
          'app_mode = production',
          'Authorization: Bearer fixture-token',
          'https://example.test?access_token=fixture',
        ];

        for (final String input in sensitive) {
          await c.add(entry('json', input));
        }
        await c.add(entry('json', 'safe input', output: 'api_key: fixture'));

        expect(c.entries, isEmpty);
      },
    );

    test(
      'does not reject words that merely contain credential terms',
      () async {
        final HistoryController c = HistoryController();

        await c.add(entry('json', '{"monkey":"banana","secretary":"Ada"}'));

        expect(c.entries, hasLength(1));
      },
    );

    test('purges persisted sensitive entries on load', () async {
      final List<Map<String, dynamic>> stored = <Map<String, dynamic>>[
        entry('timestamp', '1717171717').toJson(),
        entry('jwt', 'fixture.jwt.value').toJson(),
        entry('json', 'CLIENT_SECRET=fixture').toJson(),
        entry('base64', 'otherwise safe', sensitive: true).toJson(),
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.history.entries': jsonEncode(stored),
      });

      final HistoryController c = await HistoryController.load();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<dynamic> persisted =
          jsonDecode(prefs.getString('mb.history.entries')!) as List<dynamic>;

      expect(c.entries, hasLength(1));
      expect(c.entries.single.utilityId, 'timestamp');
      expect(persisted, hasLength(1));
      expect(
        (persisted.single as Map<String, dynamic>)['utilityId'],
        'timestamp',
      );
    });

    test(
      'overwrites a corrupt persisted payload instead of retaining it',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'mb.history.entries': 'raw-credential-fixture',
        });

        final HistoryController c = await HistoryController.load();
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        expect(c.entries, isEmpty);
        expect(
          prefs.getString('mb.history.entries'),
          isNot(contains('raw-credential-fixture')),
        );
      },
    );
  });
}
