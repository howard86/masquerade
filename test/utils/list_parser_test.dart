import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/list_parser.dart';

void main() {
  group('ListParser.parse — delimiter precedence', () {
    test('newline-separated lines', () {
      expect(ListParser.parse('BTC\nETH\nSOL'), <String>['BTC', 'ETH', 'SOL']);
    });

    test('comma present keeps multi-word items', () {
      expect(ListParser.parse('New York, LA'), <String>['New York', 'LA']);
    });

    test('semicolon and pipe split', () {
      expect(ListParser.parse('a;b|c'), <String>['a', 'b', 'c']);
    });

    test('tab splits', () {
      expect(ListParser.parse('a\tb\tc'), <String>['a', 'b', 'c']);
    });

    test('whitespace fallback when no structural delimiter', () {
      expect(ListParser.parse('BTC ETH HYPE'), <String>['BTC', 'ETH', 'HYPE']);
    });

    test('mixed delimiters', () {
      expect(ListParser.parse('BTC, ETH; HYPE|SOL'), <String>[
        'BTC',
        'ETH',
        'HYPE',
        'SOL',
      ]);
    });
  });

  group('ListParser.parse — markers, trimming, quotes', () {
    test('strips unordered bullet markers', () {
      expect(
        ListParser.parse('- BTCUSDT\n* ETHUSDT\n+ SOLUSDT\n• XRPUSDT'),
        <String>['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'XRPUSDT'],
      );
    });

    test('strips ordered markers (1. and 2))', () {
      expect(ListParser.parse('1. XRP\n2) TON'), <String>['XRP', 'TON']);
    });

    test('version string without trailing space survives', () {
      expect(ListParser.parse('1.2.3\n4.5.6'), <String>['1.2.3', '4.5.6']);
    });

    test('trims items and drops blank lines', () {
      expect(ListParser.parse('  BTC  \n\n   \n ETH '), <String>['BTC', 'ETH']);
    });

    test('unwraps surrounding double and single quotes', () {
      expect(ListParser.parse('"BTC", "ETH", \'SOL\''), <String>[
        'BTC',
        'ETH',
        'SOL',
      ]);
    });

    test('strips bullet then quotes together', () {
      expect(ListParser.parse('- "BTC"'), <String>['BTC']);
    });

    test('blank input yields empty list', () {
      expect(ListParser.parse(''), isEmpty);
      expect(ListParser.parse('   \n\t '), isEmpty);
    });
  });

  group('ListParser.transform', () {
    const List<String> items = <String>['eth', 'BTC', 'eth', 'Sol'];

    test('uppercase then dedupe collapses case-equal items', () {
      expect(
        ListParser.transform(items, caseMode: ListCase.upper, dedupe: true),
        <String>['ETH', 'BTC', 'SOL'],
      );
    });

    test('dedupe keeps first occurrence, no case change', () {
      expect(
        ListParser.transform(<String>['BTC', 'btc', 'ETH'], dedupe: true),
        <String>['BTC', 'btc', 'ETH'],
      );
    });

    test('sort is case-insensitive', () {
      expect(
        ListParser.transform(<String>['eth', 'BTC', 'sol'], sort: true),
        <String>['BTC', 'eth', 'sol'],
      );
    });

    test('lowercase maps every item', () {
      expect(
        ListParser.transform(<String>['BTC', 'Eth'], caseMode: ListCase.lower),
        <String>['btc', 'eth'],
      );
    });
  });

  group('ListParser.join', () {
    const List<String> items = <String>['BTC', 'ETH'];

    test('joins with separator value', () {
      expect(ListParser.join(items, separator: ', '), 'BTC, ETH');
      expect(ListParser.join(items, separator: '\n'), 'BTC\nETH');
    });

    test('quote-wraps each item', () {
      expect(
        ListParser.join(items, separator: ',', quote: true),
        '"BTC","ETH"',
      );
      expect(
        ListParser.join(items, separator: ',', quote: true, quoteChar: "'"),
        "'BTC','ETH'",
      );
    });

    test('brackets the whole output', () {
      expect(
        ListParser.join(items, separator: ',', quote: true, bracket: true),
        '["BTC","ETH"]',
      );
    });
  });
}
