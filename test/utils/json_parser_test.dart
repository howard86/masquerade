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
}
