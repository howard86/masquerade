import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/toml_parser.dart';

void main() {
  group('TomlParser.parse', () {
    test('parses table with scalars', () {
      final TomlParseResult r = TomlParser.parse(
        '[server]\nport = 8080\nhost = "localhost"',
      );
      expect(r, isA<TomlOk>());
      expect((r as TomlOk).value, <String, Object?>{
        'server': <String, Object?>{'port': 8080, 'host': 'localhost'},
      });
    });

    test('parses bare key/value at root', () {
      final TomlOk ok = TomlParser.parse('title = "TOML"\ncount = 3') as TomlOk;
      expect(ok.value, <String, Object?>{'title': 'TOML', 'count': 3});
    });

    test('parses array of tables', () {
      final TomlOk ok =
          TomlParser.parse('[[items]]\nname = "a"\n[[items]]\nname = "b"')
              as TomlOk;
      expect(ok.value, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'a'},
          <String, Object?>{'name': 'b'},
        ],
      });
    });

    test('reports the exact line on malformed TOML', () {
      // The parser consumes valid key/values then expects EOF, so it reports
      // the position just past the last good line — line 2, col 6 (right after
      // `b = 2`), where the `!!!` garbage on line 3 stops it. Lines are 1-based.
      final TomlParseResult r = TomlParser.parse('a = 1\nb = 2\n!!!');
      expect(r, isA<TomlErr>());
      final TomlErr err = r as TomlErr;
      expect(err.line, 2);
      expect(err.column, 6);
    });

    test('empty input returns TomlErr', () {
      expect(TomlParser.parse(''), isA<TomlErr>());
      expect(TomlParser.parse('   \n'), isA<TomlErr>());
    });

    test('parsed value is jsonEncode-safe', () {
      final TomlOk ok =
          TomlParser.parse('[s]\nport = 80\nhost = "x"') as TomlOk;
      expect(jsonEncode(ok.value), '{"s":{"port":80,"host":"x"}}');
    });
  });

  group('TomlParser.emit', () {
    test('round-trips through parse→emit→parse', () {
      final Map<String, Object?> value = <String, Object?>{
        'server': <String, Object?>{
          'port': 8080,
          'host': 'localhost',
          'tags': <String>['a', 'b'],
        },
      };
      final String toml = TomlParser.emit(value);
      final TomlOk reparsed = TomlParser.parse(toml) as TomlOk;
      expect(reparsed.value, value);
    });

    test('rejects top-level list with ArgumentError', () {
      expect(() => TomlParser.emit(<int>[1, 2]), throwsA(isA<ArgumentError>()));
    });

    test('rejects top-level scalar with ArgumentError', () {
      expect(() => TomlParser.emit(42), throwsA(isA<ArgumentError>()));
    });
  });
}
