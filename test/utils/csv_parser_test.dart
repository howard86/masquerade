import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/csv_parser.dart';

void main() {
  group('CsvParser.parse', () {
    test('detects a header and comma-delimited rows', () {
      final CsvOk parsed = CsvParser.parse('a,b\n1,2\n3,4') as CsvOk;

      expect(parsed.delimiter, ',');
      expect(parsed.header, <String>['a', 'b']);
      expect(parsed.rows, <List<String>>[
        <String>['1', '2'],
        <String>['3', '4'],
      ]);
    });

    test('handles BOM, CRLF, empty cells, and optional trailing newline', () {
      final CsvOk parsed =
          CsvParser.parse('\ufeffa,b,c\r\n1,,3\r\n', hasHeader: true) as CsvOk;

      expect(parsed.header, <String>['a', 'b', 'c']);
      expect(parsed.rows, <List<String>>[
        <String>['1', '', '3'],
      ]);

      final CsvOk trailingEmpty =
          CsvParser.parse('a,b\r\n1,2\r\n,\r\n', hasHeader: true) as CsvOk;
      expect(trailingEmpty.rows.last, <String>['', '']);
    });

    test('handles quoted delimiters, doubled quotes, and embedded CRLF', () {
      final CsvOk parsed =
          CsvParser.parse(
                'a,b\r\n"hello, world","He said ""hi""\r\nagain"',
                hasHeader: true,
              )
              as CsvOk;

      expect(parsed.rows.single.first, 'hello, world');
      expect(parsed.rows.single.last, 'He said "hi"\r\nagain');
    });

    test('supports one-column quoted records', () {
      final CsvOk parsed = CsvParser.parse('a\n"He said ""hi"""') as CsvOk;
      expect(parsed.header, <String>['a']);
      expect(parsed.rows.single.single, 'He said "hi"');
    });

    test('supports a delimiter inside a quoted one-column record', () {
      final CsvOk parsed = CsvParser.parse('name\n"Smith, John"') as CsvOk;

      expect(parsed.delimiter, ',');
      expect(parsed.header, <String>['name']);
      expect(parsed.rows.single.single, 'Smith, John');
    });

    test('detects tab and semicolon deterministically', () {
      expect((CsvParser.parse('a\tb\n1\t2') as CsvOk).delimiter, '\t');
      expect((CsvParser.parse('a;b\n1;2') as CsvOk).delimiter, ';');
      expect((CsvParser.parse('a,b;c\n1,2;3') as CsvOk).delimiter, ',');
    });

    test('allows an explicit no-header override', () {
      final CsvOk parsed =
          CsvParser.parse('name,city\nAda,London', hasHeader: false) as CsvOk;
      expect(parsed.header, isNull);
      expect(parsed.rows.first, <String>['name', 'city']);
    });

    test('rejects malformed quotes and characters after a closing quote', () {
      expect(CsvParser.parse('a,b\n"x,1'), isA<CsvErr>());
      expect(CsvParser.parse('a,b\nx"y,1'), isA<CsvErr>());
      expect(CsvParser.parse('a,b\n"x" y,1'), isA<CsvErr>());
      expect(CsvParser.parse('a,b\n "x",1'), isA<CsvErr>());
    });

    test('rejects ragged rows for each supported delimiter', () {
      for (final String input in <String>[
        'a,b\n1,2,3',
        'a\tb\n1\t2\t3',
        'a;b\n1;2;3',
      ]) {
        final CsvErr error = CsvParser.parse(input) as CsvErr;
        expect(error.message, contains('columns'));
      }
    });

    test('rejects empty and duplicate headers when selected', () {
      expect(
        (CsvParser.parse(',b\n1,2', hasHeader: true) as CsvErr).message,
        contains('must not be empty'),
      );
      expect(
        (CsvParser.parse('a,a\n1,2', hasHeader: true) as CsvErr).message,
        contains('unique'),
      );
    });

    test('enforces UTF-8 input bytes and cell bounds', () {
      expect(CsvParser.parse('😀' * 262145), isA<CsvErr>());
      expect(
        CsvParser.parse('a\n${'x' * (CsvParser.maxCellChars + 1)}'),
        isA<CsvErr>(),
      );
    });
  });

  group('CsvParser.parse error precedence and slicing', () {
    String? error(String input, {String? delimiter}) =>
        switch (CsvParser.parse(input, delimiter: delimiter)) {
          CsvErr(:final String message) => message,
          CsvOk() => null,
        };

    test('a later structural or limit error outranks a column mismatch', () {
      expect(error('a,b\nc\nd,e'), 'Row 2 has 1 columns; expected 2.');
      expect(
        error('a,b\nc\nd,"e"x'),
        'Unexpected character after closing quote at character 12.',
      );
      expect(
        error('a,b\nc\nd,e"f'),
        'Unexpected quote in an unquoted field at character 10.',
      );
      expect(error('a,b\nc\n"unclosed'), 'Unclosed quoted field.');
      expect(
        error('a,b\nc\n${List<String>.filled(10001, 'a,b').join('\n')}'),
        'Input exceeds the 10,000 row limit.',
      );
    });

    test('quoted cells decode escapes and count them toward the cap', () {
      final CsvOk parsed =
          CsvParser.parse('id,name\n1,"Ada ""Countess"" Lovelace"\r\n2,Bob\n')
              as CsvOk;
      expect(parsed.header, <String>['id', 'name']);
      expect(parsed.rows, <List<String>>[
        <String>['1', 'Ada "Countess" Lovelace'],
        <String>['2', 'Bob'],
      ]);
      final String x = 'x' * 65535;
      final CsvOk atCap = CsvParser.parse('a,"$x"""', delimiter: ',') as CsvOk;
      expect(atCap.rows.single.last, '$x"');
      expect(error('a,"${x}x"""\nb,c'), 'A cell exceeds 65,536 characters.');
      expect(error('a,${x}xx"'), 'A cell exceeds 65,536 characters.');
    });

    test('picks the consistent delimiter even when another mismatches', () {
      final CsvOk parsed = CsvParser.parse('a\tb\nc,d\te\nf\tg,h') as CsvOk;
      expect(parsed.delimiter, '\t');
      expect(parsed.rows, <List<String>>[
        <String>['c,d', 'e'],
        <String>['f', 'g,h'],
      ]);
      expect(() => parsed.rows.first.add('x'), throwsUnsupportedError);
    });
  });

  group('JSON conversion', () {
    test('uses objects with a header and arrays without one', () {
      final CsvOk withHeader =
          CsvParser.parse('a,b\n1,2', hasHeader: true) as CsvOk;
      final CsvOk withoutHeader =
          CsvParser.parse('1,2\n3,4', hasHeader: false) as CsvOk;

      expect(jsonDecode(CsvParser.toJson(withHeader)), <Object?>[
        <String, Object?>{'a': '1', 'b': '2'},
      ]);
      expect(jsonDecode(CsvParser.toJson(withoutHeader)), <Object?>[
        <Object?>['1', '2'],
        <Object?>['3', '4'],
      ]);
    });

    test('round-trips exact strings including formula-like values', () {
      const String input = 'name,note\r\nAda,"=SUM(1,2)"\r\nBob,"a""b"';
      final CsvOk first = CsvParser.parse(input, hasHeader: true) as CsvOk;
      final String emitted = CsvParser.fromJson(CsvParser.toJson(first));
      final CsvOk second = CsvParser.parse(emitted, hasHeader: true) as CsvOk;

      expect(second.header, first.header);
      expect(second.rows, first.rows);
    });

    test('quotes only values requiring RFC 4180 quoting', () {
      expect(
        CsvParser.fromJson('[{"a":"x,y","b":"a\\"b","c":"x\\ny"}]'),
        'a,b,c\r\n"x,y","a""b","x\ny"',
      );
    });

    test('accepts object keys in a different order', () {
      expect(
        CsvParser.fromJson('[{"a":"1","b":"2"},{"b":"4","a":"3"}]'),
        'a,b\r\n1,2\r\n3,4',
      );
    });

    test('rejects ragged, mixed, nested, null, and invalid delimiter JSON', () {
      expect(
        () => CsvParser.fromJson('[["a"],["b","c"]]'),
        throwsFormatException,
      );
      expect(
        () => CsvParser.fromJson('[["a"],{"0":"b"}]'),
        throwsFormatException,
      );
      expect(
        () => CsvParser.fromJson('[[{"nested":true}]]'),
        throwsFormatException,
      );
      expect(() => CsvParser.fromJson('[[null]]'), throwsFormatException);
      expect(
        () => CsvParser.fromJson('[[]]', delimiter: '|'),
        throwsFormatException,
      );
    });

    test('fromJsonRecords returns the written records and scalar flag', () {
      final ({String csv, List<List<String>> records, bool typedScalars})
      objects = CsvParser.fromJsonRecords('[{"a":"x,y","b":1}]');
      expect(objects.csv, 'a,b\r\n"x,y",1');
      expect(objects.records, <List<String>>[
        <String>['a', 'b'],
        <String>['x,y', '1'],
      ]);
      expect(objects.typedScalars, isTrue);
      final ({String csv, List<List<String>> records, bool typedScalars})
      arrays = CsvParser.fromJsonRecords('[["s"],["t"]]', delimiter: ';');
      expect(arrays.csv, 's\r\nt');
      expect(arrays.typedScalars, isFalse);
      expect(CsvParser.fromJsonRecords('[]').records, isEmpty);
    });

    test('rejects duplicate headers before object conversion', () {
      final CsvOk parsed = CsvOk(
        delimiter: ',',
        hasHeader: true,
        header: <String>['a', 'a'],
        rows: <List<String>>[
          <String>['1', '2'],
        ],
      );
      expect(() => CsvParser.toJson(parsed), throwsFormatException);
    });
  });
}
