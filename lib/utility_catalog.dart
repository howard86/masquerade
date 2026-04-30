import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import 'screens/detail/base64_screen.dart';
import 'screens/detail/bps_screen.dart';
import 'screens/detail/color_screen.dart';
import 'screens/detail/json_screen.dart';
import 'screens/detail/number_base_screen.dart';
import 'screens/detail/timestamp_screen.dart';
import 'theme/mb_colors.dart';
import 'widgets/mb/mb_icons.dart';

enum MBCategory { numeric, time, encoding, visual }

extension MBCategoryLabel on MBCategory {
  String get label => switch (this) {
    MBCategory.numeric => 'Numeric',
    MBCategory.time => 'Time',
    MBCategory.encoding => 'Encoding',
    MBCategory.visual => 'Visual',
  };
}

class UtilityDescriptor {
  const UtilityDescriptor({
    required this.id,
    required this.name,
    required this.icon,
    required this.tint,
    required this.category,
    required this.synonyms,
    required this.builder,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color tint;
  final MBCategory category;
  final List<String> synonyms;
  final WidgetBuilder builder;
}

/// Static catalog of every utility shipped in the app.
class UtilityCatalog {
  const UtilityCatalog._();

  static final List<UtilityDescriptor> all = <UtilityDescriptor>[
    UtilityDescriptor(
      id: 'number_base',
      name: 'Number Base',
      icon: MBIcons.binary,
      tint: MBColors.light().info,
      category: MBCategory.numeric,
      synonyms: <String>['hex', 'binary', 'octal', 'decimal', 'base'],
      builder: (BuildContext _) => const NumberBaseScreen(),
    ),
    UtilityDescriptor(
      id: 'timestamp',
      name: 'Timestamp',
      icon: MBIcons.clock,
      tint: MBColors.light().accent,
      category: MBCategory.time,
      synonyms: <String>['epoch', 'unix', 'iso', 'date', 'time'],
      builder: (BuildContext _) => const TimestampScreen(),
    ),
    UtilityDescriptor(
      id: 'json',
      name: 'JSON',
      icon: MBIcons.brackets,
      tint: const Color(0xFF8B5CF6),
      category: MBCategory.encoding,
      synonyms: <String>['pretty', 'minify', 'tree', 'parse'],
      builder: (BuildContext _) => const JSONScreen(),
    ),
    UtilityDescriptor(
      id: 'base64',
      name: 'Base64',
      icon: MBIcons.textCase,
      tint: const Color(0xFF0EA5E9),
      category: MBCategory.encoding,
      synonyms: <String>['encode', 'decode', 'b64', 'url-safe'],
      builder: (BuildContext _) => const Base64Screen(),
    ),
    UtilityDescriptor(
      id: 'color',
      name: 'Color',
      icon: MBIcons.drop,
      tint: const Color(0xFFEC4899),
      category: MBCategory.visual,
      synonyms: <String>['hex', 'rgb', 'hsl', 'oklch', 'contrast', 'wcag'],
      builder: (BuildContext _) => const ColorScreen(),
    ),
    UtilityDescriptor(
      id: 'bps',
      name: 'bps · % · decimal',
      icon: MBIcons.pct,
      tint: const Color(0xFFF59E0B),
      category: MBCategory.numeric,
      synonyms: <String>['basis points', 'percent', 'rate', 'finance'],
      builder: (BuildContext _) => const BpsScreen(),
    ),
  ];

  static UtilityDescriptor byId(String id) =>
      all.firstWhere((UtilityDescriptor u) => u.id == id);

  static List<UtilityDescriptor> byCategory(MBCategory category) =>
      all.where((UtilityDescriptor u) => u.category == category).toList();
}
