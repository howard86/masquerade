import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:masquerade/utils/encoding_parser.dart';

const int _samples = 15;

void main(List<String> arguments) {
  if (arguments.firstOrNull == 'corpus') {
    _verifyCorpus();
    return;
  }
  final int kib = int.parse(arguments.firstOrNull ?? '64');
  final String input = _fixture(kib * 1024);
  for (int i = 0; i < 3; i++) {
    _detect(input);
  }
  final List<int> samples = <int>[];
  String digest = '';
  for (int i = 0; i < _samples; i++) {
    final Stopwatch watch = Stopwatch()..start();
    digest = _detect(input);
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  stdout.writeln(
    '${kib}KiB digest=$digest median=${samples[samples.length ~/ 2]} '
    'p95=${samples[((samples.length * 0.95).ceil() - 1)]} samples=$samples',
  );
}

String _detect(String input) {
  final String trimmed = input.trim();
  if (!EncodingParser.isBase64(trimmed)) return 'rejected';
  final List<int> bytes = base64Decode(trimmed);
  if (bytes.isEmpty || !bytes.every(_isPrintableByte)) return 'rejected';
  final String decoded = utf8.decode(bytes);
  return sha256.convert(utf8.encode('base64|0.9|$decoded')).toString();
}

bool _isPrintableByte(int byte) =>
    byte == 0x09 ||
    byte == 0x0a ||
    byte == 0x0d ||
    (byte >= 0x20 && byte <= 0x7e);

String _fixture(int encodedLength) {
  final int bytes = encodedLength ~/ 4 * 3;
  const String text = 'Masquerade base64 detector fixture line 0123456789.\n';
  final String source = List<String>.filled(
    (bytes ~/ text.length) + 1,
    text,
  ).join().substring(0, bytes);
  final String encoded = base64Encode(utf8.encode(source));
  if (encoded.length != encodedLength) throw StateError('fixture length');
  return encoded;
}

void _verifyCorpus() {
  final List<String> corpus = <String>[];
  const List<String> symbols = <String>['A', 'B', '+', '/', '=', '@', ' '];
  void addExhaustive(String prefix, int remaining) {
    corpus.add(prefix);
    if (remaining == 0) return;
    for (final String symbol in symbols) {
      addExhaustive('$prefix$symbol', remaining - 1);
    }
  }

  addExhaustive('', 6);
  final Random random = Random(8675309);
  const String randomSymbols =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=@-_ \n';
  for (int i = 0; i < 50000; i++) {
    corpus.add(
      List<String>.generate(
        random.nextInt(65),
        (_) => randomSymbols[random.nextInt(randomSymbols.length)],
      ).join(),
    );
  }
  final StringBuffer decisions = StringBuffer();
  for (final String input in corpus) {
    final bool baseline = EncodingParser.isBase64(input);
    final bool grammar = _grammarAccepts(input);
    final bool decoder = _decoderAccepts(input);
    if (baseline != grammar || grammar != decoder) {
      throw StateError(
        'mismatch ${jsonEncode(input)} baseline=$baseline '
        'grammar=$grammar decoder=$decoder',
      );
    }
    decisions.write(baseline ? '1' : '0');
  }
  stdout.writeln(
    'corpus=${corpus.length} digest='
    '${sha256.convert(utf8.encode(decisions.toString()))}',
  );
}

bool _grammarAccepts(String input) {
  final String trimmed = input.trim();
  if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(trimmed) ||
      trimmed.length % 4 != 0) {
    return false;
  }
  const String alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  if (trimmed.endsWith('==')) {
    return alphabet.indexOf(trimmed[trimmed.length - 3]) & 15 == 0;
  }
  if (trimmed.endsWith('=')) {
    return alphabet.indexOf(trimmed[trimmed.length - 2]) & 3 == 0;
  }
  return true;
}

bool _decoderAccepts(String input) {
  final String trimmed = input.trim();
  if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(trimmed) ||
      trimmed.length % 4 != 0) {
    return false;
  }
  try {
    base64Decode(trimmed);
    return true;
  } on FormatException {
    return false;
  }
}
