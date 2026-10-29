import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/mojibake_parser.dart';

MojibakeOk _ok(String input, {MojibakeCodec? codec}) {
  final MojibakeResult r = MojibakeParser.parse(input, codec: codec);
  expect(r, isA<MojibakeOk>(), reason: input);
  return r as MojibakeOk;
}

void main() {
  group('MojibakeParser.parse', () {
    test('repairs the Mac Roman box-drawing table', () {
      const String input =
          '‚îå‚îÄ‚îÄ‚î¨‚îÄ‚îÄ‚îê\n'
          '‚îÇ adminPassword      ‚îÇ grafana-admin ‚Üí password            ‚îÇ\n'
          '‚îî‚îÄ‚îÄ‚î¥‚îÄ‚îÄ‚îò';
      final MojibakeOk r = _ok(input);
      expect(
        r.text,
        '┌──┬──┐\n'
        '│ adminPassword      │ grafana-admin → password            │\n'
        '└──┴──┘',
      );
      expect(r.codec, MojibakeCodec.macRoman);
      expect(r.passes, 1);
      expect(r.fixedSequences, greaterThan(10));
    });

    test('repairs Windows-1252 accents and smart quotes', () {
      final MojibakeOk a = _ok('CafÃ©');
      expect(a.text, 'Café');
      expect(a.codec, MojibakeCodec.windows1252);
      expect(a.fixedSequences, 1);

      final MojibakeOk b = _ok('itâ€™s');
      expect(b.text, 'it’s');
      expect(b.codec, MojibakeCodec.windows1252);
    });

    test('repairs Latin-1 text with raw C1 controls', () {
      final MojibakeOk r = _ok('itâ\u0080\u0099s');
      expect(r.text, 'it’s');
      expect(r.codec, MojibakeCodec.latin1);
    });

    test('repairs double-encoded text over two passes', () {
      // "é" -> Ã© -> UTF-8 bytes read as CP1252 again.
      final MojibakeOk r = _ok('CafÃƒÂ©');
      expect(r.text, 'Café');
      expect(r.passes, 2);
    });

    test('repairs broken runs and leaves correct text alone', () {
      final MojibakeOk r = _ok('naïve café vs CafÃ© — ok');
      expect(r.text, 'naïve café vs Café — ok');
    });

    test('repairs the valid part of a run with a stray character', () {
      expect(_ok('Ã©é').text, 'éé');
    });

    test('forced codec overrides auto selection', () {
      final MojibakeOk r = _ok('CafÃ©', codec: MojibakeCodec.latin1);
      expect(r.codec, MojibakeCodec.latin1);
      expect(r.text, 'Café');
      expect(
        MojibakeParser.parse('CafÃ©', codec: MojibakeCodec.macRoman),
        isA<MojibakeErr>(),
      );
    });

    test('strips a UTF-8 BOM and NBSP mojibake', () {
      expect(_ok('ï»¿hello').text, '﻿hello');
      expect(_ok('aÂ b').text, 'a b');
    });

    test('genuine text is not altered', () {
      for (final String s in <String>[
        'café',
        '日本語',
        'naïve — test',
        'ok 😀',
        'plain ascii',
        'Ünïcödé ß ñ',
      ]) {
        final MojibakeResult r = MojibakeParser.parse(s);
        expect(r, isA<MojibakeErr>(), reason: s);
        expect((r as MojibakeErr).message, 'No mojibake found.');
      }
    });

    test('empty and oversized input are errors', () {
      expect(MojibakeParser.parse(''), isA<MojibakeErr>());
      expect(
        MojibakeParser.parse('a' * (MojibakeParser.maxInputBytes + 1)),
        isA<MojibakeErr>(),
      );
    });
  });

  group('MojibakeParser.looksLike', () {
    test('true for typical mojibake', () {
      expect(MojibakeParser.looksLike('CafÃ©'), isTrue);
      expect(MojibakeParser.looksLike('itâ€™s'), isTrue);
      expect(MojibakeParser.looksLike('‚îå‚îÄ‚îÄ‚îê'), isTrue);
      expect(MojibakeParser.looksLike('ï»¿data'), isTrue);
      expect(MojibakeParser.looksLike('5Â km'), isTrue);
    });

    test('false for ordinary text', () {
      expect(MojibakeParser.looksLike(''), isFalse);
      expect(MojibakeParser.looksLike('hello'), isFalse);
      expect(MojibakeParser.looksLike('café naïve — Ünï 日本語'), isFalse);
      expect(MojibakeParser.looksLike('Ã alone'), isFalse);
    });
  });
}
