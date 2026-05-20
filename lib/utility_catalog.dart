import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'utils/bps_parser.dart';
import 'utils/bytes_parser.dart';
import 'utils/color_parser.dart';
import 'utils/cron_nl_parser.dart';
import 'utils/cron_parser.dart';
import 'utils/encoding_parser.dart';
import 'utils/json_parser.dart';
import 'utils/number_base_parser.dart';
import 'widgets/mq/mq_icons.dart';
import 'widgets/mq/tool_action_bar.dart';
import 'widgets/tool_bodies/base64_body.dart';
import 'widgets/tool_bodies/bps_body.dart';
import 'widgets/tool_bodies/bytes_body.dart';
import 'widgets/tool_bodies/color_body.dart';
import 'widgets/tool_bodies/cron_body.dart';
import 'widgets/tool_bodies/json_body.dart';
import 'widgets/tool_bodies/list_body.dart';
import 'widgets/tool_bodies/math_body.dart';
import 'widgets/tool_bodies/number_base_body.dart';
import 'widgets/tool_bodies/qr_code_body.dart';
import 'widgets/tool_bodies/seed_source.dart';
import 'widgets/tool_bodies/timestamp_body.dart';

/// Routes a cross-tool "Open in X" tap from any tool body's footer back to
/// the host screen, which expands the target tool's inline card seeded with
/// [input]. Fired by `OpenInFooter` and the QR scan-result chips.
typedef OpenInToolCallback = void Function(UtilityDescriptor u, String input);

/// Builds an embeddable tool body for inline rendering inside an
/// `InlineToolCard`. Receives the optional seed input and how it arrived
/// ([SeedSource]) so the body can decide whether to record history
/// immediately (paste) or behind a typing-debounce. [onSwitchTool] lets a
/// body pipe its current output into another tool without leaving Home.
/// When [actionBar] is non-null, the body should bind its paste/clear
/// handlers on the controller so the detail route can render a pinned bar.
typedef UtilityBuilder =
    Widget Function(
      BuildContext context, {
      String? initialInput,
      SeedSource seedSource,
      OpenInToolCallback? onSwitchTool,
      ToolActionBarController? actionBar,
    });

class UtilityDescriptor {
  const UtilityDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tint,
    required this.synonyms,
    required this.builder,
    required this.detect,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color tint;
  final List<String> synonyms;
  final UtilityBuilder builder;
  final bool Function(String input) detect;
}

/// Static catalog of every utility shipped in the app.
class UtilityCatalog {
  const UtilityCatalog._();

  static final List<UtilityDescriptor> all = <UtilityDescriptor>[
    UtilityDescriptor(
      id: 'number_base',
      name: 'Number Base',
      description: 'Hex · binary · octal · decimal',
      icon: MqIcons.binary,
      tint: const Color(0xFF3B6DD6),
      synonyms: <String>['hex', 'binary', 'octal', 'decimal', 'base'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => NumberBaseBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectNumberBase,
    ),
    UtilityDescriptor(
      id: 'timestamp',
      name: 'Timestamp',
      description: 'Unix s/ms · ISO 8601',
      icon: MqIcons.clock,
      tint: const Color(0xFF00B8C4),
      synonyms: <String>['epoch', 'unix', 'iso', 'date', 'time'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => TimestampBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectTimestamp,
    ),
    UtilityDescriptor(
      id: 'cron',
      name: 'Cron',
      description: 'Cron schedules and natural language',
      icon: MqIcons.cron,
      tint: const Color(0xFFD946EF),
      synonyms: <String>['cron', 'schedule', 'crontab'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => CronBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectCron,
    ),
    UtilityDescriptor(
      id: 'json',
      name: 'JSON',
      description: 'Pretty · minify · tree',
      icon: MqIcons.brackets,
      tint: const Color(0xFF8B5CF6),
      synonyms: <String>['pretty', 'minify', 'tree', 'parse'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => JSONBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectJson,
    ),
    UtilityDescriptor(
      id: 'base64',
      name: 'Base64',
      description: 'Encode / decode · URL-safe',
      icon: MqIcons.textCase,
      tint: const Color(0xFF0EA5E9),
      synonyms: <String>['encode', 'decode', 'b64', 'url-safe'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => Base64Body(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectBase64,
    ),
    UtilityDescriptor(
      id: 'color',
      name: 'Color',
      description: 'HEX · RGB · HSL · OKLCH',
      icon: MqIcons.drop,
      tint: const Color(0xFFEC4899),
      synonyms: <String>['hex', 'rgb', 'hsl', 'oklch', 'contrast', 'wcag'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => ColorBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectColor,
    ),
    UtilityDescriptor(
      id: 'math',
      name: 'Math',
      description: 'Expression evaluator · pi · sin · log',
      icon: MqIcons.calculator,
      tint: const Color(0xFFEF4444),
      synonyms: <String>[
        'calc',
        'calculator',
        'expression',
        'evaluate',
        'arithmetic',
      ],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => MathBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectMath,
    ),
    UtilityDescriptor(
      id: 'bps',
      name: 'bps · % · decimal',
      description: 'Basis points ↔ % ↔ decimal',
      icon: MqIcons.pct,
      tint: const Color(0xFFF59E0B),
      synonyms: <String>['basis points', 'percent', 'rate', 'finance'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => BpsBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectBps,
    ),
    UtilityDescriptor(
      id: 'bytes',
      name: 'Bytes',
      description: 'Byte array ↔ text (UTF-8)',
      icon: MqIcons.bytes,
      tint: const Color(0xFF22C55E),
      synonyms: <String>['buffer', 'bytes', 'array', 'utf8', 'utf-8', 'decode'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => BytesBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectBytes,
    ),
    UtilityDescriptor(
      id: 'list',
      name: 'List',
      description: 'Split ↔ join · separators',
      icon: MqIcons.list,
      tint: const Color(0xFF84CC16),
      synonyms: <String>[
        'split',
        'join',
        'delimiter',
        'separator',
        'csv',
        'comma',
        'lines',
      ],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
          }) => ListToolBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
          ),
      detect: _detectList,
    ),
    UtilityDescriptor(
      id: 'qr_code',
      name: 'QR Code',
      description: 'Scan · generate QR',
      icon: MqIcons.qrCode,
      tint: const Color(0xFF6366F1),
      synonyms: <String>['qr', 'barcode', 'scan', 'generate'],
      builder:
          (
            BuildContext _, {
            String? initialInput,
            SeedSource seedSource = SeedSource.none,
            OpenInToolCallback? onSwitchTool,
            ToolActionBarController? actionBar,
          }) => QrCodeBody(
            initialInput: initialInput,
            seedSource: seedSource,
            onSwitchTool: onSwitchTool,
            actionBar: actionBar,
          ),
      detect: _detectQrCode,
    ),
  ];

  static UtilityDescriptor byId(String id) =>
      all.firstWhere((UtilityDescriptor u) => u.id == id);

  /// Returns descriptors whose `detect` predicate accepts [input], in catalog
  /// order. When shape-based detection finds nothing and [input] looks like a
  /// short query (alphabetic, ≤ 20 chars), falls through to a synonym/name
  /// scorer so typing "unix" surfaces Timestamp and "minify" surfaces JSON.
  /// Returns empty when [input] trims to empty.
  static List<UtilityDescriptor> detectAll(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return const <UtilityDescriptor>[];
    final List<UtilityDescriptor> shape = all
        .where((UtilityDescriptor u) => u.detect(input))
        .toList();
    if (shape.isNotEmpty) return shape;
    return _synonymMatch(trimmed);
  }

  static final RegExp _queryShape = RegExp(r'^[a-zA-Z0-9\- ]{1,20}$');

  static List<UtilityDescriptor> _synonymMatch(String query) {
    if (!_queryShape.hasMatch(query)) return const <UtilityDescriptor>[];
    final String q = query.toLowerCase();
    final List<({UtilityDescriptor u, int score})> ranked =
        <({UtilityDescriptor u, int score})>[];
    for (final UtilityDescriptor u in all) {
      final int s = _scoreTool(u, q);
      if (s > 0) ranked.add((u: u, score: s));
    }
    ranked.sort(
      (
        ({UtilityDescriptor u, int score}) a,
        ({UtilityDescriptor u, int score}) b,
      ) => b.score.compareTo(a.score),
    );
    return ranked
        .map((({UtilityDescriptor u, int score}) e) => e.u)
        .toList(growable: false);
  }

  static int _scoreTool(UtilityDescriptor u, String q) {
    final String name = u.name.toLowerCase();
    if (name == q) return 100;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase() == q) return 90;
    }
    if (name.startsWith(q)) return 70;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase().startsWith(q)) return 60;
    }
    if (name.contains(q)) return 40;
    for (final String syn in u.synonyms) {
      if (syn.toLowerCase().contains(q)) return 30;
    }
    return 0;
  }
}

bool _detectJson(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  if (!(t.startsWith('{') || t.startsWith('['))) return false;
  return JSONParser.parse(t) is JSONOk;
}

bool _detectColor(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  // Reject base-prefixed numbers — those should fire Number Base only.
  final String lower = t.toLowerCase();
  if (lower.startsWith('0x') ||
      lower.startsWith('0b') ||
      lower.startsWith('0o')) {
    return false;
  }
  return MqColorParser.parse(t) != null;
}

bool _detectTimestamp(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  // Accept only the unambiguous direct forms here; defer base64/hex variants
  // to their own tools to avoid double-counting.
  final int? n = int.tryParse(t);
  if (n != null) {
    // Reject obviously-tiny numbers that are noise (e.g. "1", "42").
    return n.abs() >= 100000000;
  }
  try {
    DateTime.parse(t);
    return true;
  } catch (_) {
    return false;
  }
}

bool _detectNumberBase(String input) =>
    NumberBaseParser.parse(input.trim()) != null;

bool _detectCron(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  if (CronParser.parseSyntax(t).isSuccess) return true;
  return CronNlParser.parse(t).isSuccess;
}

bool _detectBase64(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  if (!EncodingParser.isBase64(t)) return false;
  // Reject pure hex (those already fire Number Base / Color); require either
  // padding, or chars outside the hex alphabet.
  final bool isHexAlphabet = RegExp(r'^[0-9a-fA-F]+$').hasMatch(t);
  if (isHexAlphabet && !t.contains('=')) return false;
  // Reject inputs where the decoded bytes are not printable text — those tend
  // to be coincidental matches like a 4-char alphanumeric token.
  try {
    final List<int> bytes = (const Base64Decoder()).convert(t);
    if (bytes.isEmpty) return false;
    return bytes.every(_isPrintableByte);
  } catch (_) {
    return false;
  }
}

bool _isPrintableByte(int b) =>
    b == 0x09 || b == 0x0A || b == 0x0D || (b >= 0x20 && b <= 0x7E);

bool _detectBps(String input) {
  final String t = input.trim().toLowerCase();
  if (t.isEmpty) return false;
  if (BpsParser.parse(t) == null) return false;
  // Without an explicit suffix, only suggest bps for small decimals (≤ 1).
  // Plain large integers like a unix timestamp shouldn't trigger this chip.
  final bool hasSuffix =
      t.endsWith('bps') || t.endsWith('bp') || t.endsWith('%');
  if (hasSuffix) return true;
  final double? n = double.tryParse(t);
  return n != null && n.abs() <= 1.0;
}

// QR has no input shape — entry is via grid tile or the home scan button.
bool _detectQrCode(String _) => false;

// Operator must sit between two *operand-shaped* tokens. Eliminates false
// positives like `0.5%` (unary-suffix percent) and `hsl(184, 100%, 38%)`
// (commas/parens flank the `%`).
final RegExp _mathBinaryOp = RegExp(
  r'[\dA-Za-z_)]\s*[+\-*/%^]\s*[\dA-Za-z_(\-]',
);

// ISO 8601 dates share the `-` character with subtraction; the timestamp tool
// owns these, so skip math detection when the input matches that shape.
final RegExp _isoDateShape = RegExp(r'^\d{4}-\d{2}-\d{2}([T ].*)?$');

final RegExp _mathIdent = RegExp(r'[A-Za-z_]+');

const Set<String> _mathFunctions = <String>{
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'log',
  'ln',
  'sqrt',
  'abs',
  'floor',
  'ceil',
  'round',
  'min',
  'max',
};
const Set<String> _mathConsts = <String>{'pi', 'e', 'ans'};

bool _detectMath(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  if (_isoDateShape.hasMatch(t)) return false;
  // A bulleted/numbered list reads as subtraction across line breaks
  // (`…T\n- E…`); defer those to the List tool.
  if (_detectList(input)) return false;
  if (_mathBinaryOp.hasMatch(t)) return true;
  for (final RegExpMatch m in _mathIdent.allMatches(t.toLowerCase())) {
    final String w = m.group(0)!;
    if (_mathFunctions.contains(w) || _mathConsts.contains(w)) return true;
  }
  return false;
}

bool _detectBytes(String input) {
  final String t = input.trim();
  if (t.isEmpty) return false;
  // Cheap reject before allocating tokens/Uint8List: must start with a digit
  // or `[`, anything else can't be an integer list.
  final int first = t.codeUnitAt(0);
  final bool startsOk =
      first == 0x5B /* [ */ || (first >= 0x30 && first <= 0x39) /* 0-9 */;
  if (!startsOk) return false;
  final BytesParseResult r = BytesParser.parse(t);
  if (r is! BytesParseOk) return false;
  // Single tokens stay with Number Base / Timestamp.
  return r.bytes.length >= 2;
}

// Fires only on multi-line bulleted/numbered lists: at least two non-blank
// lines, a strict majority starting with a list marker. Keeps the chip quiet
// for prose, CSV, JSON, and single lines.
final RegExp _listMarker = RegExp(r'^\s*([-*+•]|\d+[.)])\s+');

bool _detectList(String input) {
  final List<String> lines = input
      .split('\n')
      .where((String l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return false;
  final int marked = lines.where(_listMarker.hasMatch).length;
  return marked * 2 > lines.length;
}
