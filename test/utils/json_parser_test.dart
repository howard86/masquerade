import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/json_parser.dart';

void main() {
  group('JSONParser', () {
    test('parses valid JSON object', () {
      final JSONParseResult r = JSONParser.parse('{"a":1}');
      expect(r, isA<JSONOk>());
      expect((r as JSONOk).value.value, <String, Object?>{'a': 1});
    });

    test('reports line:column on invalid JSON', () {
      final JSONParseResult r = JSONParser.parse('{"a":}');
      expect(r, isA<JSONErr>());
      final JSONErr err = r as JSONErr;
      expect(err.error.line, 1);
      expect(err.error.column, 6);
    });

    test('reports line on multi-line invalid JSON', () {
      final JSONParseResult r = JSONParser.parse('{\n  "a": 1,\n  "b":\n}');
      expect(r, isA<JSONErr>());
      final JSONErr err = r as JSONErr;
      expect(err.error.line, 4);
    });

    test('pretty + minify roundtrip', () {
      final JSONParseResult r = JSONParser.parse('{"a":[1,2],"b":"x"}');
      expect(r, isA<JSONOk>());
      final Object? value = (r as JSONOk).value.value;
      expect(JSONParser.minify(value), '{"a":[1,2],"b":"x"}');
      final String pretty = JSONParser.pretty(value);
      expect(pretty.contains('\n'), isTrue);
      expect(pretty.contains('  '), isTrue);
    });

    test('rejects empty input', () {
      expect(JSONParser.parse(''), isA<JSONErr>());
      expect(JSONParser.parse('   '), isA<JSONErr>());
    });
  });

  group('JSONParser auto-fix', () {
    test('trailing comma before } is fixable', () {
      final JSONErr err = JSONParser.parse('{"a":1,}') as JSONErr;
      expect(err.error.fixable, isTrue);
      final String fixed = err.error.fixedText!;
      expect(JSONParser.parse(fixed), isA<JSONOk>());
    });

    test('trailing comma before ] is fixable', () {
      final JSONErr err = JSONParser.parse('[1, 2, 3,]') as JSONErr;
      expect(err.error.fixable, isTrue);
      expect(JSONParser.parse(err.error.fixedText!), isA<JSONOk>());
    });

    test('multiple trailing commas across nested structures are fixed', () {
      final JSONErr err =
          JSONParser.parse('{"a":[1,2,],"b":{"c":3,},}') as JSONErr;
      expect(err.error.fixable, isTrue);
      expect(JSONParser.parse(err.error.fixedText!), isA<JSONOk>());
    });

    test('unterminated string at EOF is fixable', () {
      final JSONErr err = JSONParser.parse('{"a":"foo') as JSONErr;
      expect(err.error.fixable, isTrue);
      expect(JSONParser.parse(err.error.fixedText!), isA<JSONOk>());
    });

    test('missing value is NOT fixable', () {
      final JSONErr err = JSONParser.parse('{"a":}') as JSONErr;
      expect(err.error.fixable, isFalse);
      expect(err.error.fixedText, isNull);
    });

    test('comma inside string is not treated as trailing', () {
      final JSONErr err = JSONParser.parse('{"a":"x,","b":') as JSONErr;
      expect(err.error.fixable, isFalse);
    });
  });
  group('JSONParser suggestFix', () {
    test('suggestFix: false skips the auto-fix probe', () {
      final JSONErr err =
          JSONParser.parse('{"a":1,}', suggestFix: false) as JSONErr;
      expect(err.error.fixable, isFalse);
      expect(err.error.fixedText, isNull);
      final JSONErr full = JSONParser.parse('{"a":1,}') as JSONErr;
      expect(err.error.message, full.error.message);
      expect(err.error.line, full.error.line);
      expect(err.error.column, full.error.column);
    });

    test('suggestFix: false still parses valid input', () {
      final JSONOk ok =
          JSONParser.parse('{"a":[1]}', suggestFix: false) as JSONOk;
      expect(ok.value.value, <String, Object?>{
        'a': <Object?>[1],
      });
    });
  });

  group('JSONParser.tree', () {
    // The pre-StringBuffer renderer, kept as the equivalence oracle.
    String reference(Object? v, int depth) {
      final String indent = '  ' * depth;
      if (v is Map) {
        if (v.isEmpty) return '{}';
        final List<String> lines = <String>['{'];
        v.forEach((Object? k, Object? val) {
          lines.add('$indent  $k: ${reference(val, depth + 1)}');
        });
        lines.add('$indent}');
        return lines.join('\n');
      }
      if (v is List) {
        if (v.isEmpty) return '[]';
        final List<String> lines = <String>['['];
        for (int i = 0; i < v.length; i++) {
          lines.add('$indent  [$i] ${reference(v[i], depth + 1)}');
        }
        lines.add('$indent]');
        return lines.join('\n');
      }
      return '$v';
    }

    test('matches the per-level join renderer', () {
      final List<Object?> values = <Object?>[
        null,
        42,
        'text',
        <String, Object?>{},
        <Object?>[],
        <String, Object?>{
          'a': 1,
          'b': <Object?>[
            true,
            null,
            <String, Object?>{},
            <Object?>[],
            <String, Object?>{'c': 'd\ne'},
          ],
          'e': <String, Object?>{
            'f': <Object?>[
              <Object?>[1, 2],
            ],
          },
        },
      ];
      Object? deep = 'leaf';
      for (int i = 0; i < 30; i++) {
        deep = <String, Object?>{
          'k$i': i,
          'child': deep,
          'list': <Object?>[i],
        };
      }
      values.add(deep);
      for (final Object? v in values) {
        expect(JSONParser.tree(v), reference(v, 0));
      }
    });
  });
}
