import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/url_parser.dart';

void main() {
  String? encode(String s) {
    final UrlResult r = UrlParser.parse(s, mode: UrlMode.encode);
    return r is UrlOk ? r.output : null;
  }

  String? decode(String s) {
    final UrlResult r = UrlParser.parse(s, mode: UrlMode.decode);
    return r is UrlOk ? r.output : null;
  }

  group('UrlParser percent encode/decode round-trips', () {
    const List<String> samples = <String>[
      'hello world',
      'a b  c', // multiple spaces
      'café résumé 你好 😀', // unicode
      r'? & = / # +', // reserved chars
      'name=value&other=thing',
      'https://example.com/path?q=1&r=2#frag',
      '', // empty
    ];

    for (final String s in samples) {
      test('decode(encode(${s.isEmpty ? '<empty>' : s})) == original', () {
        final String? enc = encode(s);
        expect(enc, isNotNull);
        expect(decode(enc!), s);
      });
    }

    test('encodeComponent escapes every reserved char', () {
      final String? enc = encode('&=?/#+ ');
      expect(enc, '%26%3D%3F%2F%23%2B%20');
    });
  });

  group('UrlParser decode errors (no throw)', () {
    test('bad hex digits return an error', () {
      expect(UrlParser.parse('%ZZ', mode: UrlMode.decode), isA<UrlError>());
    });

    test('truncated multibyte sequence returns an error', () {
      expect(UrlParser.parse('%E0%A4', mode: UrlMode.decode), isA<UrlError>());
    });

    test('error message names percent-encoding', () {
      final UrlResult r = UrlParser.parse('%ZZ', mode: UrlMode.decode);
      expect((r as UrlError).message, contains('percent-encoding'));
    });
  });

  group('UrlParser.splitQuery', () {
    test('splits bare query into ordered pairs', () {
      expect(UrlParser.splitQuery('a=1&b=2&c=3'), const <QueryPair>[
        QueryPair('a', '1'),
        QueryPair('b', '2'),
        QueryPair('c', '3'),
      ]);
    });

    test('preserves order and duplicate keys', () {
      expect(UrlParser.splitQuery('k=1&k=2&j=3'), const <QueryPair>[
        QueryPair('k', '1'),
        QueryPair('k', '2'),
        QueryPair('j', '3'),
      ]);
    });

    test('keeps empty values and empty keys', () {
      expect(UrlParser.splitQuery('a=&=b&c'), const <QueryPair>[
        QueryPair('a', ''),
        QueryPair('', 'b'),
        QueryPair('c', ''),
      ]);
    });

    test('drops scheme/host before the first ? and trailing #fragment', () {
      expect(
        UrlParser.splitQuery('https://x.com/p?q=hi&r=yo#section'),
        const <QueryPair>[QueryPair('q', 'hi'), QueryPair('r', 'yo')],
      );
    });

    test('percent-decodes keys and values', () {
      expect(
        UrlParser.splitQuery('q=hello%20world&city=S%C3%A3o'),
        const <QueryPair>[
          QueryPair('q', 'hello world'),
          QueryPair('city', 'São'),
        ],
      );
    });

    test('treats + as space in query values', () {
      expect(UrlParser.splitQuery('q=a+b'), const <QueryPair>[
        QueryPair('q', 'a b'),
      ]);
    });

    test('returns empty for non-query text', () {
      expect(UrlParser.splitQuery('just some words'), isEmpty);
      expect(UrlParser.splitQuery('nothinghere'), isEmpty);
    });
  });

  group('UrlParser.buildQuery round-trip', () {
    test('rebuild then split reproduces the pairs', () {
      const List<QueryPair> pairs = <QueryPair>[
        QueryPair('q', 'hello world'),
        QueryPair('tag', 'a&b'),
        QueryPair('empty', ''),
      ];
      final String built = UrlParser.buildQuery(pairs);
      expect(UrlParser.splitQuery(built), pairs);
    });
  });

  group('UrlParser.parse exposes query pairs alongside the transform', () {
    test('decode of a full URL surfaces its query pairs', () {
      final UrlResult r = UrlParser.parse(
        'https://x.com/s?q=cats&n=10',
        mode: UrlMode.decode,
      );
      expect(r, isA<UrlOk>());
      expect((r as UrlOk).pairs, const <QueryPair>[
        QueryPair('q', 'cats'),
        QueryPair('n', '10'),
      ]);
    });
  });
}
