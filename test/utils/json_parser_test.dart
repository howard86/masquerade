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
}
