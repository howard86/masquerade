import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

enum UnicodeNormalization { nfc, nfd, nfkc, nfkd }

extension UnicodeNormalizationLabel on UnicodeNormalization {
  String get label => name.toUpperCase();
}

class UnicodeInspectorException implements Exception {
  const UnicodeInspectorException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnicodeGrapheme {
  const UnicodeGrapheme({
    required this.text,
    required this.display,
    required this.codePoints,
    required this.utf8Bytes,
    required this.markers,
    required this.codePointCount,
    required this.utf8ByteCount,
    required this.detailsTruncated,
  });

  final String text;
  final String display;
  final List<int> codePoints;
  final List<int> utf8Bytes;
  final List<String> markers;
  final int codePointCount;
  final int utf8ByteCount;
  final bool detailsTruncated;

  String get codePointLabel =>
      '${codePoints.map(_formatCodePoint).join(' ')}${codePoints.length < codePointCount ? ' … (+${codePointCount - codePoints.length})' : ''}';
  String get byteLabel =>
      '${utf8Bytes.map((int byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}${utf8Bytes.length < utf8ByteCount ? ' … (+${utf8ByteCount - utf8Bytes.length})' : ''}';
}

class LineEndingSummary {
  const LineEndingSummary({
    required this.lf,
    required this.crlf,
    required this.cr,
  });

  final int lf;
  final int crlf;
  final int cr;

  int get total => lf + crlf + cr;
  bool get mixed => <int>[lf, crlf, cr].where((int n) => n > 0).length > 1;

  String get label => 'LF $lf · CRLF $crlf · CR $cr';
}

class UnicodeInspection {
  const UnicodeInspection._({
    required this.input,
    required this.graphemes,
    required this.graphemeCount,
    required this.codePointCount,
    required this.utf8ByteCount,
    required this.normalized,
    required this.lineEndings,
    required this.warnings,
    required this.truncated,
  });

  final String input;
  final List<UnicodeGrapheme> graphemes;
  final int graphemeCount;
  final int codePointCount;
  final int utf8ByteCount;
  final Map<UnicodeNormalization, String> normalized;
  final LineEndingSummary lineEndings;
  final List<String> warnings;
  final bool truncated;

  String normalizedAs(UnicodeNormalization form) => normalized[form]!;
  bool changes(UnicodeNormalization form) => normalizedAs(form) != input;
  bool get canRouteBytes =>
      utf8ByteCount <= UnicodeStringInspector.maxRouteBytes;

  String get bytesInput {
    if (!canRouteBytes) {
      throw const UnicodeInspectorException(
        'Text is too large to route to Bytes.',
      );
    }
    return utf8.encode(input).join(' ');
  }
}

abstract final class UnicodeStringInspector {
  static const int maxInputCodeUnits = 262144;
  static const int maxInputBytes = 524288;
  static const int maxDisplayedGraphemes = 1000;
  static const int maxDetailsPerGrapheme = 128;
  static const int maxCodePointsPerGrapheme = 1024;
  static const int maxRouteBytes = 65536;
  static const int maxRouteCodeUnits = 65536;

  static bool canRouteText(String text) => text.length <= maxRouteCodeUnits;

  static String visiblePreview(
    String value, {
    int maxGraphemes = 120,
    int maxCodeUnits = 256,
    int maxOutputCharacters = 512,
  }) {
    final StringBuffer result = StringBuffer();
    int graphemes = 0;
    int codeUnits = 0;
    bool truncated = false;
    outer:
    for (final String cluster in value.characters) {
      if (graphemes >= maxGraphemes ||
          codeUnits + cluster.length > maxCodeUnits) {
        truncated = true;
        break;
      }
      for (final int rune in cluster.runes) {
        final String? marker = _markerFor(rune);
        final String piece = marker == null
            ? String.fromCharCode(rune)
            : '⟦$marker⟧';
        if (result.length + piece.length > maxOutputCharacters) {
          truncated = true;
          break outer;
        }
        result.write(piece);
      }
      graphemes++;
      codeUnits += cluster.length;
    }
    return '${result.toString()}${truncated ? '… (${value.length} code units)' : ''}';
  }

  static UnicodeInspection parse(String input) {
    if (input.length > maxInputCodeUnits) {
      throw const UnicodeInspectorException(
        'Text exceeds the 262,144-character limit.',
      );
    }
    if (_hasUnpairedSurrogate(input)) {
      throw const UnicodeInspectorException('Text contains malformed UTF-16.');
    }
    final List<int> allBytes = utf8.encode(input);
    if (allBytes.length > maxInputBytes) {
      throw const UnicodeInspectorException('Text exceeds the 512 KiB limit.');
    }

    final List<UnicodeGrapheme> graphemes = <UnicodeGrapheme>[];
    int graphemeCount = 0;
    final Set<String> invisibleNames = <String>{};
    bool hasBidi = false;

    for (final String cluster in input.characters) {
      graphemeCount++;
      final List<int> runes = <int>[];
      int runeCount = 0;
      final List<String> markers = <String>[];
      final StringBuffer display = StringBuffer();
      for (final int rune in cluster.runes) {
        runeCount++;
        if (runeCount > maxCodePointsPerGrapheme) {
          throw const UnicodeInspectorException(
            'A grapheme cluster exceeds the 1,024-code-point limit.',
          );
        }
        if (runes.length < maxDetailsPerGrapheme) runes.add(rune);
        final String? marker = _markerFor(rune);
        if (marker == null) {
          if (display.length < maxDetailsPerGrapheme) {
            display.writeCharCode(rune);
          }
        } else {
          if (markers.length < maxDetailsPerGrapheme &&
              !markers.contains(marker)) {
            markers.add(marker);
          }
          invisibleNames.add(marker);
          if (display.length < maxDetailsPerGrapheme) {
            display.write('⟦$marker⟧');
          }
        }
        hasBidi |= _isBidi(rune);
      }
      if (graphemes.length < maxDisplayedGraphemes) {
        final List<int> clusterBytes = utf8.encode(cluster);
        final bool detailsTruncated =
            runeCount > maxDetailsPerGrapheme ||
            clusterBytes.length > maxDetailsPerGrapheme;
        graphemes.add(
          UnicodeGrapheme(
            text: cluster,
            display: '${display.toString()}${detailsTruncated ? '…' : ''}',
            codePoints: List<int>.unmodifiable(runes),
            utf8Bytes: List<int>.unmodifiable(
              clusterBytes.take(maxDetailsPerGrapheme),
            ),
            markers: List<String>.unmodifiable(markers),
            codePointCount: runeCount,
            utf8ByteCount: clusterBytes.length,
            detailsTruncated: detailsTruncated,
          ),
        );
      }
    }

    final List<String> scripts = <String>[
      if (_latinScript.hasMatch(input)) 'Latin',
      if (_greekScript.hasMatch(input)) 'Greek',
      if (_cyrillicScript.hasMatch(input)) 'Cyrillic',
    ];
    final List<String> warnings = <String>[
      if (invisibleNames.isNotEmpty)
        'Invisible or control characters: ${invisibleNames.take(12).join(', ')}${invisibleNames.length > 12 ? ', …' : ''}.',
      if (hasBidi) 'Bidirectional controls can change visual text ordering.',
      if (scripts.length > 1)
        'Possible confusable text: mixed ${scripts.join('/')} scripts.',
    ];
    final LineEndingSummary endings = _lineEndings(input);
    if (endings.mixed) warnings.add('Mixed line endings detected.');

    return UnicodeInspection._(
      input: input,
      graphemes: List<UnicodeGrapheme>.unmodifiable(graphemes),
      graphemeCount: graphemeCount,
      codePointCount: input.runes.length,
      utf8ByteCount: allBytes.length,
      normalized: Map<UnicodeNormalization, String>.unmodifiable(
        <UnicodeNormalization, String>{
          UnicodeNormalization.nfc: unorm.nfc(input),
          UnicodeNormalization.nfd: unorm.nfd(input),
          UnicodeNormalization.nfkc: unorm.nfkc(input),
          UnicodeNormalization.nfkd: unorm.nfkd(input),
        },
      ),
      lineEndings: endings,
      warnings: List<String>.unmodifiable(warnings),
      truncated: graphemeCount > maxDisplayedGraphemes,
    );
  }
}

final RegExp _latinScript = RegExp(r'\p{Script=Latin}', unicode: true);
final RegExp _greekScript = RegExp(r'\p{Script=Greek}', unicode: true);
final RegExp _cyrillicScript = RegExp(r'\p{Script=Cyrillic}', unicode: true);

String? _markerFor(int rune) {
  final String? named = const <int, String>{
    0x0000: 'NUL',
    0x0009: 'TAB',
    0x000a: 'LF',
    0x000d: 'CR',
    0x0020: 'SPACE',
    0x00a0: 'NO-BREAK SPACE',
    0x00ad: 'SOFT HYPHEN',
    0x061c: 'ARABIC LETTER MARK',
    0x200b: 'ZERO WIDTH SPACE',
    0x200c: 'ZERO WIDTH NON-JOINER',
    0x200d: 'ZERO WIDTH JOINER',
    0x200e: 'LEFT-TO-RIGHT MARK',
    0x200f: 'RIGHT-TO-LEFT MARK',
    0x2028: 'LINE SEPARATOR',
    0x2029: 'PARAGRAPH SEPARATOR',
    0x202a: 'LEFT-TO-RIGHT EMBEDDING',
    0x202b: 'RIGHT-TO-LEFT EMBEDDING',
    0x202c: 'POP DIRECTIONAL FORMATTING',
    0x202d: 'LEFT-TO-RIGHT OVERRIDE',
    0x202e: 'RIGHT-TO-LEFT OVERRIDE',
    0x202f: 'NARROW NO-BREAK SPACE',
    0x2060: 'WORD JOINER',
    0x2066: 'LEFT-TO-RIGHT ISOLATE',
    0x2067: 'RIGHT-TO-LEFT ISOLATE',
    0x2068: 'FIRST STRONG ISOLATE',
    0x2069: 'POP DIRECTIONAL ISOLATE',
    0x3000: 'IDEOGRAPHIC SPACE',
    0xfe0e: 'TEXT PRESENTATION SELECTOR',
    0xfe0f: 'EMOJI PRESENTATION SELECTOR',
    0xfeff: 'BYTE ORDER MARK',
  }[rune];
  if (named != null) return named;
  if ((rune >= 0x0001 && rune <= 0x001f) ||
      (rune >= 0x007f && rune <= 0x009f)) {
    return 'CONTROL ${_formatCodePoint(rune)}';
  }
  if ((rune >= 0x0300 && rune <= 0x036f) ||
      (rune >= 0x1ab0 && rune <= 0x1aff) ||
      (rune >= 0x1dc0 && rune <= 0x1dff) ||
      (rune >= 0x20d0 && rune <= 0x20ff) ||
      (rune >= 0xfe20 && rune <= 0xfe2f)) {
    return 'COMBINING MARK ${_formatCodePoint(rune)}';
  }
  return null;
}

bool _isBidi(int rune) =>
    rune == 0x061c ||
    rune == 0x200e ||
    rune == 0x200f ||
    (rune >= 0x202a && rune <= 0x202e) ||
    (rune >= 0x2066 && rune <= 0x2069);

bool _hasUnpairedSurrogate(String input) {
  int index = 0;
  while (index < input.length) {
    final int unit = input.codeUnitAt(index++);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (index >= input.length) return true;
      final int next = input.codeUnitAt(index++);
      if (next < 0xdc00 || next > 0xdfff) return true;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return true;
    }
  }
  return false;
}

LineEndingSummary _lineEndings(String input) {
  int lf = 0;
  int crlf = 0;
  int cr = 0;
  int index = 0;
  while (index < input.length) {
    final int code = input.codeUnitAt(index++);
    if (code == 0x0d) {
      if (index < input.length && input.codeUnitAt(index) == 0x0a) {
        crlf++;
        index++;
      } else {
        cr++;
      }
    } else if (code == 0x0a) {
      lf++;
    }
  }
  return LineEndingSummary(lf: lf, crlf: crlf, cr: cr);
}

String _formatCodePoint(int rune) =>
    'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}';
