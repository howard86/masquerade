import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import 'screens/detail/base64_screen.dart';
import 'screens/detail/bps_screen.dart';
import 'screens/detail/color_screen.dart';
import 'screens/detail/json_screen.dart';
import 'screens/detail/number_base_screen.dart';
import 'screens/detail/timestamp_screen.dart';
import 'theme/mq_colors.dart';
import 'utils/bps_parser.dart';
import 'utils/color_parser.dart';
import 'utils/encoding_parser.dart';
import 'utils/json_parser.dart';
import 'utils/number_base_parser.dart';
import 'widgets/mq/mq_icons.dart';

typedef UtilityBuilder =
    Widget Function(BuildContext context, {String? initialInput});

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
      tint: MqColors.light().info,
      synonyms: <String>['hex', 'binary', 'octal', 'decimal', 'base'],
      builder: (BuildContext _, {String? initialInput}) =>
          NumberBaseScreen(initialInput: initialInput),
      detect: _detectNumberBase,
    ),
    UtilityDescriptor(
      id: 'timestamp',
      name: 'Timestamp',
      description: 'Unix s/ms · ISO 8601',
      icon: MqIcons.clock,
      tint: MqColors.light().accent,
      synonyms: <String>['epoch', 'unix', 'iso', 'date', 'time'],
      builder: (BuildContext _, {String? initialInput}) =>
          TimestampScreen(initialInput: initialInput),
      detect: _detectTimestamp,
    ),
    UtilityDescriptor(
      id: 'json',
      name: 'JSON',
      description: 'Pretty · minify · tree',
      icon: MqIcons.brackets,
      tint: const Color(0xFF8B5CF6),
      synonyms: <String>['pretty', 'minify', 'tree', 'parse'],
      builder: (BuildContext _, {String? initialInput}) =>
          JSONScreen(initialInput: initialInput),
      detect: _detectJson,
    ),
    UtilityDescriptor(
      id: 'base64',
      name: 'Base64',
      description: 'Encode / decode · URL-safe',
      icon: MqIcons.textCase,
      tint: const Color(0xFF0EA5E9),
      synonyms: <String>['encode', 'decode', 'b64', 'url-safe'],
      builder: (BuildContext _, {String? initialInput}) =>
          Base64Screen(initialInput: initialInput),
      detect: _detectBase64,
    ),
    UtilityDescriptor(
      id: 'color',
      name: 'Color',
      description: 'HEX · RGB · HSL · OKLCH',
      icon: MqIcons.drop,
      tint: const Color(0xFFEC4899),
      synonyms: <String>['hex', 'rgb', 'hsl', 'oklch', 'contrast', 'wcag'],
      builder: (BuildContext _, {String? initialInput}) =>
          ColorScreen(initialInput: initialInput),
      detect: _detectColor,
    ),
    UtilityDescriptor(
      id: 'bps',
      name: 'bps · % · decimal',
      description: 'Basis points ↔ % ↔ decimal',
      icon: MqIcons.pct,
      tint: const Color(0xFFF59E0B),
      synonyms: <String>['basis points', 'percent', 'rate', 'finance'],
      builder: (BuildContext _, {String? initialInput}) =>
          BpsScreen(initialInput: initialInput),
      detect: _detectBps,
    ),
  ];

  static UtilityDescriptor byId(String id) =>
      all.firstWhere((UtilityDescriptor u) => u.id == id);

  /// Returns descriptors whose `detect` predicate accepts [input], in catalog
  /// order. Returns empty when [input] trims to empty.
  static List<UtilityDescriptor> detectAll(String input) {
    if (input.trim().isEmpty) return const <UtilityDescriptor>[];
    return all.where((UtilityDescriptor u) => u.detect(input)).toList();
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
