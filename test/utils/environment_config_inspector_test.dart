import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/environment_config_inspector.dart';
import 'package:masquerade/utils/json_parser.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/utils/yaml_parser.dart';

void main() {
  group('EnvironmentConfigInspector', () {
    test('parses env quoting, comments, escapes, and export prefixes', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(r'''
# comment
export API_HOST="https://example.com/a#b"
GREETING='hello world'
ESCAPED="line\nnext\tvalue\$"
HASH=value # note
''', format: ConfigFormat.environment);

      expect(result.commentCount, 1);
      expect(result.entries.map((ConfigEntry e) => e.value), <String>[
        'https://example.com/a#b',
        'hello world',
        'line\nnext\tvalue\$',
        'value',
      ]);
      expect(result.entries.first.exported, isTrue);
      expect(result.normalized(), startsWith('export API_HOST='));
      final ConfigInspection reparsed = EnvironmentConfigInspector.parse(
        result.normalized(),
        format: ConfigFormat.environment,
      );
      expect(
        reparsed.entries.map((ConfigEntry e) => e.value),
        result.entries.map((ConfigEntry e) => e.value),
      );
    });

    test('accepts BOM, quoted multiline, and backslash continuation', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        '\uFEFFMULTI="first\nsecond"\nJOIN=one\\\n  two',
        format: ConfigFormat.environment,
      );

      expect(result.entries[0].value, 'first\nsecond');
      expect(result.entries[0].line, 1);
      expect(result.entries[1].value, 'onetwo');
      expect(
        EnvironmentConfigInspector.parse(
          result.normalized(),
          format: ConfigFormat.environment,
        ).entries.map((ConfigEntry e) => e.value),
        result.entries.map((ConfigEntry e) => e.value),
      );
    });

    test('parses Java properties escapes and continuation', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        'escaped\\ key = hello\\nworld\nunicode=\\u2603\njoined=one\\\n  two\n',
        format: ConfigFormat.properties,
      );

      expect(result.entries[0].key, 'escaped key');
      expect(result.entries[0].value, 'hello\nworld');
      expect(result.entries[1].value, '☃');
      expect(result.entries[2].value, 'onetwo');
      final ConfigInspection reparsed = EnvironmentConfigInspector.parse(
        result.normalized(),
        format: ConfigFormat.properties,
      );
      expect(
        reparsed.entries.map((ConfigEntry e) => (e.key, e.value)),
        result.entries.map((ConfigEntry e) => (e.key, e.value)),
      );
    });

    test('properties normalize controls, leading spaces, and comment keys', () {
      final ConfigInspection parsed = EnvironmentConfigInspector.parse(
        r'\#key=\ leading'
        '\n'
        r'\!bang=\u0001control',
        format: ConfigFormat.properties,
      );
      final String normalized = parsed.normalized();
      final ConfigInspection reparsed = EnvironmentConfigInspector.parse(
        normalized,
        format: ConfigFormat.properties,
      );

      expect(normalized, contains(r'\#key=\ leading'));
      expect(normalized, contains(r'\!bang=\u0001control'));
      expect(
        reparsed.entries.map((ConfigEntry entry) => (entry.key, entry.value)),
        parsed.entries.map((ConfigEntry entry) => (entry.key, entry.value)),
      );
    });

    test('properties normalize lone and paired surrogate escapes safely', () {
      final ConfigInspection parsed = EnvironmentConfigInspector.parse(
        r'lone=\uD800'
        '\n'
        r'face=\uD83D\uDE00',
        format: ConfigFormat.properties,
      );
      final String normalized = parsed.normalized();
      final ConfigInspection reparsed = EnvironmentConfigInspector.parse(
        normalized,
        format: ConfigFormat.properties,
      );

      expect(normalized, contains(r'lone=\ud800'));
      expect(normalized, contains(r'face=\ud83d\ude00'));
      expect(reparsed.entries[0].value.codeUnits, <int>[0xd800]);
      expect(reparsed.entries[1].value, '😀');
      final ConfigConversion conversion = parsed.convert();
      expect(conversion.available, isFalse);
      expect(conversion.warning, contains('YAML'));
    });

    test('rejects caller-supplied raw lone surrogates generically', () {
      final String malformed = String.fromCharCode(0xd800);
      expect(
        () => EnvironmentConfigInspector.parse(
          'A=$malformed',
          format: ConfigFormat.environment,
        ),
        throwsA(
          isA<ConfigInspectorException>().having(
            (ConfigInspectorException error) => error.message,
            'message',
            'Input contains invalid UTF-16.',
          ),
        ),
      );
    });

    test('headers use case-insensitive duplicate rules and preserve order', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        'X-Test: first\nx-test: second\nAccept: text/plain',
        format: ConfigFormat.headers,
      );

      expect(result.duplicates.single.key, 'X-Test');
      expect(result.duplicates.single.lines, <int>[1, 2]);
      expect(result.entries[1].occurrence, 2);
      expect(result.normalized(), contains('X-Test: first\nx-test: second'));
    });

    test('env and key/value keys remain case-sensitive', () {
      for (final ConfigFormat format in <ConfigFormat>[
        ConfigFormat.environment,
        ConfigFormat.keyValue,
      ]) {
        final ConfigInspection result = EnvironmentConfigInspector.parse(
          'KEY=one\nkey=two',
          format: format,
        );
        expect(result.duplicates, isEmpty);
      }
    });

    test('stable sorting retains duplicate occurrence order', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        'B=first\nA=middle\nB=last',
        format: ConfigFormat.keyValue,
      );
      expect(result.normalized(sort: true), 'A=middle\nB=first\nB=last');
      expect(result.duplicates.single.lines, <int>[1, 3]);
    });

    test('masks credential keys, credential URIs, and secret-like values', () {
      const String aws = 'AKIAABCDEFGHIJKLMNOP';
      const String github = 'ghp_abcdefghijklmnopqrstuvwxyz1234';
      const String slack = 'xoxb-1234567890-abcdefghijkl';
      const String jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature_value';
      final String encoded = base64.encode(
        utf8.encode('password=encoded-secret'),
      );
      final ConfigInspection result = EnvironmentConfigInspector.parse('''
DB_PASSWORD=db-secret
STRIPE_API_KEY=stripe-secret
AWS_SECRET_ACCESS_KEY=aws-secret
WEBHOOK_SECRET=hook-secret
SIGNING_KEY=sign-secret
DATABASE_URL=postgres://user:db-pass@localhost/app
REDIS_URL=redis://user:redis-pass@localhost/0
PUBLIC_AWS=$aws
PUBLIC_GITHUB=$github
PUBLIC_SLACK=$slack
PUBLIC_JWT=$jwt
PUBLIC_ENCODED=$encoded
PUBLIC_PERCENT=password%3Dpercent-secret
token_count=42
secretary_name=Ada
''', format: ConfigFormat.environment);

      expect(result.hadSensitiveInput, isTrue);
      expect(
        result.entries
            .take(13)
            .every(
              (ConfigEntry entry) => entry.value == SensitiveDataPolicy.mask,
            ),
        isTrue,
      );
      expect(result.entries[13].value, '42');
      expect(result.entries[14].value, 'Ada');
      final String allOutput = <String>[
        result.normalized(),
        result.convert().json!,
        result.convert().yaml!,
      ].join('\n');
      for (final String secret in <String>[
        'db-secret',
        'stripe-secret',
        'aws-secret',
        'hook-secret',
        'sign-secret',
        'db-pass',
        'redis-pass',
        aws,
        github,
        slack,
        jwt,
        encoded,
        'percent-secret',
      ]) {
        expect(allOutput, isNot(contains(secret)));
      }
    });

    test('JSON and YAML conversion round-trip exact string values', () {
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        'BOOL=true\nNULL=null\nNUMBER=001\nDATE=2026-01-02\nEMPTY=',
        format: ConfigFormat.environment,
      );
      final ConfigConversion conversion = result.convert();

      expect(conversion.available, isTrue);
      final JSONOk json = JSONParser.parse(conversion.json!) as JSONOk;
      final YamlOk yaml = YamlParser.parse(conversion.yaml!) as YamlOk;
      expect(json.value.value, <String, String>{
        'BOOL': 'true',
        'NULL': 'null',
        'NUMBER': '001',
        'DATE': '2026-01-02',
        'EMPTY': '',
      });
      expect(yaml.value, json.value.value);
    });

    test('duplicate conversion is rejected instead of collapsed', () {
      final ConfigConversion conversion = EnvironmentConfigInspector.parse(
        'A=one\nA=two',
        format: ConfigFormat.environment,
      ).convert();

      expect(conversion.available, isFalse);
      expect(conversion.warning, contains('duplicate'));
    });

    test('conversion reports dropped comments and export modifiers', () {
      final ConfigConversion conversion = EnvironmentConfigInspector.parse(
        '# note\nexport A=one',
        format: ConfigFormat.environment,
      ).convert();

      expect(conversion.available, isTrue);
      expect(conversion.warning, contains('comments and export modifiers'));
    });

    test('comparison is redacted, deterministic, and occurrence-aware', () {
      final ConfigInspection a = EnvironmentConfigInspector.parse(
        'A=one\nB=old\nPASSWORD=left-secret',
        format: ConfigFormat.environment,
      );
      final ConfigInspection b = EnvironmentConfigInspector.parse(
        'B=new\nC=three\nPASSWORD=right-secret',
        format: ConfigFormat.environment,
      );
      final ConfigComparison comparison = a.compare(b);

      expect(comparison.added, 1);
      expect(comparison.removed, 1);
      expect(comparison.changed, 1);
      expect(comparison.unifiedDiff, contains(SensitiveDataPolicy.mask));
      expect(comparison.unifiedDiff, isNot(contains('left-secret')));
      expect(comparison.unifiedDiff, isNot(contains('right-secret')));
      expect(a.compare(b).unifiedDiff, comparison.unifiedDiff);
    });

    test('comparison ignores header casing and env export presentation', () {
      final ConfigComparison headers =
          EnvironmentConfigInspector.parse(
            'X-Test: same',
            format: ConfigFormat.headers,
          ).compare(
            EnvironmentConfigInspector.parse(
              'x-test: same',
              format: ConfigFormat.headers,
            ),
          );
      final ConfigComparison env =
          EnvironmentConfigInspector.parse(
            'export A=one',
            format: ConfigFormat.environment,
          ).compare(
            EnvironmentConfigInspector.parse(
              'A=one',
              format: ConfigFormat.environment,
            ),
          );

      expect(headers.identical, isTrue);
      expect(headers.unifiedDiff, isEmpty);
      expect(env.identical, isTrue);
      expect(env.unifiedDiff, isEmpty);
    });

    test('fails closed on reversible values above inspection bounds', () {
      final String oversized = 'A' * 65540;
      expect(SensitiveDataPolicy.containsSecretLikeValue(oversized), isTrue);
      expect(
        SensitiveDataPolicy.containsSecretLikeValue('%41' * 22000),
        isTrue,
      );
      expect(
        SensitiveDataPolicy.containsSecretLikeValue('ordinary value ' * 6000),
        isFalse,
      );
    });

    test('rejects secret-like keys before public model construction', () {
      for (final (ConfigFormat, String) fixture in <(ConfigFormat, String)>[
        (ConfigFormat.properties, 'ghp_abcdefghijklmnopqrstuvwxyz1234=value'),
        (ConfigFormat.headers, 'AKIAABCDEFGHIJKLMNOP: value'),
        (ConfigFormat.keyValue, 'xoxb-1234567890-abcdefghijkl=value'),
      ]) {
        expect(
          () =>
              EnvironmentConfigInspector.parse(fixture.$2, format: fixture.$1),
          throwsA(
            isA<ConfigInspectorException>().having(
              (ConfigInspectorException error) => error.message,
              'message',
              isNot(contains(fixture.$2.split(RegExp('[:=]')).first)),
            ),
          ),
        );
      }
    });

    test('auto-detects representative formats', () {
      expect(
        EnvironmentConfigInspector.detect('A=1\nB=2'),
        ConfigFormat.environment,
      );
      expect(
        EnvironmentConfigInspector.detect('Content-Type: text/plain'),
        ConfigFormat.headers,
      );
      expect(
        EnvironmentConfigInspector.detect(r'name=hello\npath=hello\u0020world'),
        ConfigFormat.properties,
      );
      expect(
        EnvironmentConfigInspector.detect('name=hello\nother=world'),
        ConfigFormat.keyValue,
      );
    });

    test(
      'rejects injection controls, folded headers, malformed quotes, and bounds',
      () {
        expect(
          () => EnvironmentConfigInspector.parse(
            'Good: one\n Injected: two',
            format: ConfigFormat.headers,
          ),
          throwsA(isA<ConfigInspectorException>()),
        );
        expect(
          () => EnvironmentConfigInspector.parse(
            'A=${'🙂' * (EnvironmentConfigInspector.maxInputCharacters ~/ 2)}',
            format: ConfigFormat.environment,
          ),
          throwsA(isA<ConfigInspectorException>()),
        );
        expect(
          () => EnvironmentConfigInspector.parse(
            'A="unterminated',
            format: ConfigFormat.environment,
          ),
          throwsA(isA<ConfigInspectorException>()),
        );
        expect(
          () => EnvironmentConfigInspector.parse(
            'A=bad\u0001value',
            format: ConfigFormat.environment,
          ),
          throwsA(isA<ConfigInspectorException>()),
        );
        expect(
          () => EnvironmentConfigInspector.parse(
            'A=${'x' * (EnvironmentConfigInspector.maxLineCharacters + 1)}',
            format: ConfigFormat.environment,
          ),
          throwsA(isA<ConfigInspectorException>()),
        );
      },
    );

    test('parses and exports 10,000 entries within a bounded budget', () {
      final String input = List<String>.generate(
        EnvironmentConfigInspector.maxLines,
        (int i) => 'KEY_$i=value_$i',
      ).join('\n');
      final Stopwatch watch = Stopwatch()..start();
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        input,
        format: ConfigFormat.environment,
      );
      final String exported = result.normalized(sort: true);
      watch.stop();

      expect(result.entries, hasLength(EnvironmentConfigInspector.maxLines));
      expect(exported, contains('KEY_9999=value_9999'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('builds 5,000 duplicate groups within a bounded budget', () {
      final String input = <String>[
        for (int index = 0; index < 5000; index++) ...<String>[
          'KEY_$index=first',
          'KEY_$index=second',
        ],
      ].join('\n');
      final Stopwatch watch = Stopwatch()..start();
      final ConfigInspection result = EnvironmentConfigInspector.parse(
        input,
        format: ConfigFormat.environment,
      );
      watch.stop();

      expect(result.duplicates, hasLength(5000));
      expect(result.duplicates.last.key, 'KEY_4999');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
