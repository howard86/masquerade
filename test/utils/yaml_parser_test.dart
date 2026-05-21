import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/yaml_parser.dart';

void main() {
  group('YamlParser.parse', () {
    test('parses scalar map', () {
      final YamlParseResult r = YamlParser.parse('a: 1\nb: hello');
      expect(r, isA<YamlOk>());
      expect((r as YamlOk).value, <String, Object?>{'a': 1, 'b': 'hello'});
      expect(r.docCount, 1);
    });

    test('parses nested map + list', () {
      final YamlParseResult r = YamlParser.parse(
        'a:\n  - 1\n  - 2\nb:\n  c: 3',
      );
      expect(r, isA<YamlOk>());
      expect((r as YamlOk).value, <String, Object?>{
        'a': <int>[1, 2],
        'b': <String, Object?>{'c': 3},
      });
    });

    test('multi-doc YAML returns first doc and docCount=N', () {
      final YamlParseResult r = YamlParser.parse('a: 1\n---\nb: 2');
      expect(r, isA<YamlOk>());
      final YamlOk ok = r as YamlOk;
      expect(ok.value, <String, Object?>{'a': 1});
      expect(ok.docCount, 2);
    });

    test('reports the exact line on malformed YAML', () {
      // Line 4 (` c: bad`) breaks indentation after the list on line 3.
      final YamlParseResult r = YamlParser.parse('a: 1\nb:\n  - x\n c: bad');
      expect(r, isA<YamlErr>());
      final YamlErr err = r as YamlErr;
      expect(err.line, 4);
    });

    test('empty input returns YamlErr', () {
      expect(YamlParser.parse(''), isA<YamlErr>());
      expect(YamlParser.parse('   \n  '), isA<YamlErr>());
    });

    test('unwraps YamlMap so jsonEncode succeeds', () {
      final YamlOk ok = YamlParser.parse('x: 1') as YamlOk;
      // Throws if value is still a YamlMap (non-encodable).
      expect(jsonEncode(ok.value), '{"x":1}');
    });
  });

  group('YamlParser.emit', () {
    test('round-trips through parse→emit→parse', () {
      final Object value = <String, Object?>{
        'a': <int>[1, 2, 3],
        'b': <String, Object?>{'c': 'hello', 'd': true},
      };
      final String yaml = YamlParser.emit(value);
      final YamlOk reparsed = YamlParser.parse(yaml) as YamlOk;
      expect(reparsed.value, value);
    });

    test('emits unquoted strings when safe', () {
      final String yaml = YamlParser.emit(<String, Object?>{'name': 'hello'});
      expect(yaml, contains('name: hello'));
      expect(yaml, isNot(contains('"hello"')));
    });
  });
}
