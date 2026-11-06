import 'dart:convert';

import 'utf8_length.dart';

/// Legacy 8-bit codecs that UTF-8 bytes are commonly mis-decoded through.
enum MojibakeCodec {
  macRoman('Mac Roman'),
  windows1252('Windows-1252'),
  latin1('Latin-1');

  const MojibakeCodec(this.label);

  final String label;
}

sealed class MojibakeResult {
  const MojibakeResult();
}

class MojibakeOk extends MojibakeResult {
  const MojibakeOk({
    required this.text,
    required this.codec,
    required this.fixedSequences,
    required this.passes,
  });

  /// The repaired text.
  final String text;

  /// The codec the text had been mis-decoded through.
  final MojibakeCodec codec;

  /// Number of garbled multi-byte sequences replaced by their real character.
  final int fixedSequences;

  /// Number of repair passes that changed something (2+ means the text was
  /// mis-decoded more than once).
  final int passes;
}

class MojibakeErr extends MojibakeResult {
  const MojibakeErr(this.message);

  final String message;
}

class _PassResult {
  const _PassResult(this.text, this.fixed, this.skipped);

  final String text;
  final int fixed;
  final int skipped;
}

class _Repair {
  const _Repair(this.ok, this.skipped);

  final MojibakeOk ok;
  final int skipped;
}

/// Repairs UTF-8 text that was decoded through a legacy 8-bit codec.
class MojibakeParser {
  const MojibakeParser._();

  static const int maxInputBytes = 1024 * 1024;
  static const int _maxPasses = 3;

  // Code points of bytes 0x80..0xFF, 128 per codec.
  static const List<int> _macRoman = <int>[
    // 0x80
    0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1,
    0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
    // 0x90
    0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3,
    0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
    // 0xA0
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
    0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
    // 0xB0
    0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211,
    0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
    // 0xC0
    0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
    0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
    // 0xD0
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA,
    0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
    // 0xE0
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1,
    0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
    // 0xF0
    0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
    0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
  ];

  // Windows-1252 0x80..0x9F. The five undefined slots (0x81 0x8D 0x8F 0x90
  // 0x9D) map to their C1 control code points, as browsers and most
  // real-world decoders do; 0xA0..0xFF are identical to Latin-1.
  static const List<int> _cp1252High = <int>[
    0x20AC,
    0x0081,
    0x201A,
    0x0192,
    0x201E,
    0x2026,
    0x2020,
    0x2021,
    0x02C6,
    0x2030,
    0x0160,
    0x2039,
    0x0152,
    0x008D,
    0x017D,
    0x008F,
    0x0090,
    0x2018,
    0x2019,
    0x201C,
    0x201D,
    0x2022,
    0x2013,
    0x2014,
    0x02DC,
    0x2122,
    0x0161,
    0x203A,
    0x0153,
    0x009D,
    0x017E,
    0x0178,
  ];

  static final Map<MojibakeCodec, Map<int, int>> _reverse =
      <MojibakeCodec, Map<int, int>>{
        MojibakeCodec.macRoman: <int, int>{
          for (int i = 0; i < 128; i++) _macRoman[i]: 0x80 + i,
        },
        MojibakeCodec.windows1252: <int, int>{
          for (int i = 0; i < 32; i++) _cp1252High[i]: 0x80 + i,
          for (int i = 0xA0; i <= 0xFF; i++) i: i,
        },
        MojibakeCodec.latin1: <int, int>{
          for (int i = 0x80; i <= 0xFF; i++) i: i,
        },
      };

  static final RegExp _signature = RegExp(
    'Ã[\u0080-¿]|â€|Â[ -¿]|ï»¿'
    '|â\u0080|‚(?:î|Ä|Ü)|√[^\\x00-\\x7F]'
    '|Ã[ƒ†‡ˆ‰Š‹ŒŽ'
    '‘’“”•–—˜™š›'
    'œžŸ]',
  );

  /// Cheap check for the typical mojibake signatures, confirmed by a real
  /// repair. Plain accented prose does not match.
  static bool looksLike(String input) {
    if (!_signature.hasMatch(input)) return false;
    return parse(input) is MojibakeOk;
  }

  /// Repairs [input]. With a null [codec] every codec is tried and the one
  /// repairing the most sequences wins (ties: fewer residual suspicious
  /// characters, then Mac Roman, Windows-1252, Latin-1).
  static MojibakeResult parse(String input, {MojibakeCodec? codec}) {
    if (input.isEmpty) return const MojibakeErr('Input is empty.');
    if (utf8LengthExceeds(input, maxInputBytes)) {
      return const MojibakeErr('Input exceeds 1 MiB.');
    }

    MojibakeOk? best;
    int bestResidual = 0;
    for (final MojibakeCodec c
        in codec == null ? MojibakeCodec.values : <MojibakeCodec>[codec]) {
      final _Repair? repair = _repair(input, c);
      if (repair == null) continue;
      final MojibakeOk ok = repair.ok;
      // Residual: mappable non-ASCII characters this codec left unrepaired.
      final int residual = repair.skipped;
      if (best == null ||
          ok.fixedSequences > best.fixedSequences ||
          (ok.fixedSequences == best.fixedSequences &&
              residual < bestResidual)) {
        best = ok;
        bestResidual = residual;
      }
    }
    return best ?? const MojibakeErr('No mojibake found.');
  }

  static _Repair? _repair(String input, MojibakeCodec codec) {
    final Map<int, int> reverse = _reverse[codec]!;
    String text = input;
    int fixed = 0;
    int passes = 0;
    int skipped = 0;
    while (passes < _maxPasses) {
      final _PassResult r = _pass(text, reverse);
      if (r.fixed == 0) break;
      text = r.text;
      fixed += r.fixed;
      skipped += r.skipped;
      passes++;
    }
    if (fixed == 0) return null;
    return _Repair(
      MojibakeOk(
        text: text,
        codec: codec,
        fixedSequences: fixed,
        passes: passes,
      ),
      skipped,
    );
  }

  static _PassResult _pass(String text, Map<int, int> reverse) {
    final List<int> runes = text.runes.toList(growable: false);
    final StringBuffer out = StringBuffer();
    int fixed = 0;
    int skipped = 0;
    int i = 0;
    while (i < runes.length) {
      if (runes[i] < 0x80) {
        out.writeCharCode(runes[i]);
        i++;
        continue;
      }
      int end = i;
      while (end < runes.length && runes[end] >= 0x80) {
        end++;
      }
      final ({int fixed, int skipped}) run = _repairRun(
        runes,
        i,
        end,
        reverse,
        out,
      );
      fixed += run.fixed;
      skipped += run.skipped;
      i = end;
    }
    return _PassResult(out.toString(), fixed, skipped);
  }

  /// Repairs the non-ASCII run `runes[start, end)` piecewise: each position
  /// either starts a valid, plausible UTF-8 sequence (replaced) or is kept
  /// verbatim.
  static ({int fixed, int skipped}) _repairRun(
    List<int> runes,
    int start,
    int end,
    Map<int, int> reverse,
    StringBuffer out,
  ) {
    int fixed = 0;
    int skipped = 0;
    int i = start;
    while (i < end) {
      final int? lead = reverse[runes[i]];
      final int len = lead == null ? 0 : _sequenceLength(lead);
      if (len == 0 || i + len > end) {
        if (lead != null) skipped++;
        out.writeCharCode(runes[i]);
        i++;
        continue;
      }
      final List<int> bytes = <int>[lead!];
      bool ok = true;
      for (int k = 1; k < len; k++) {
        final int? b = reverse[runes[i + k]];
        if (b == null) {
          ok = false;
          break;
        }
        bytes.add(b);
      }
      String? decoded;
      if (ok) {
        try {
          decoded = utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          decoded = null;
        }
      }
      // `utf8.decode` swallows a leading BOM, so keep that one by hand.
      if (decoded != null &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        decoded = '\uFEFF';
      }
      if (decoded == null ||
          decoded.isEmpty ||
          !_plausible(decoded.runes.first)) {
        skipped++;
        out.writeCharCode(runes[i]);
        i++;
        continue;
      }
      out.write(decoded);
      fixed++;
      i += len;
    }
    return (fixed: fixed, skipped: skipped);
  }

  static int _sequenceLength(int lead) {
    if (lead >= 0xC2 && lead <= 0xDF) return 2;
    if (lead >= 0xE0 && lead <= 0xEF) return 3;
    if (lead >= 0xF0 && lead <= 0xF4) return 4;
    return 0;
  }

  /// Rejects decodes that land on code points almost never typed on purpose
  /// (C1 controls, combining marks, private use, U+FFFD). This is what keeps
  /// Mac Roman from "repairing" Windows-1252 `Ã©` into a lone combining mark.
  static bool _plausible(int rune) {
    if (rune >= 0x80 && rune <= 0x9F) return false;
    if (rune >= 0x0300 && rune <= 0x036F) return false;
    if (rune >= 0xE000 && rune <= 0xF8FF) return false;
    if (rune == 0xFFFD) return false;
    return true;
  }
}
