import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import 'screens/detail/base64_screen.dart';
import 'screens/detail/bps_screen.dart';
import 'screens/detail/color_screen.dart';
import 'screens/detail/json_screen.dart';
import 'screens/detail/number_base_screen.dart';
import 'screens/detail/timestamp_screen.dart';
import 'theme/mq_colors.dart';
import 'widgets/mq/mq_icons.dart';

enum MqCategory { numeric, time, encoding, visual }

extension MqCategoryLabel on MqCategory {
  String get label => switch (this) {
    MqCategory.numeric => 'Numeric',
    MqCategory.time => 'Time',
    MqCategory.encoding => 'Encoding',
    MqCategory.visual => 'Visual',
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
  final MqCategory category;
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
      icon: MqIcons.binary,
      tint: MqColors.light().info,
      category: MqCategory.numeric,
      synonyms: <String>['hex', 'binary', 'octal', 'decimal', 'base'],
      builder: (BuildContext _) => const NumberBaseScreen(),
    ),
    UtilityDescriptor(
      id: 'timestamp',
      name: 'Timestamp',
      icon: MqIcons.clock,
      tint: MqColors.light().accent,
      category: MqCategory.time,
      synonyms: <String>['epoch', 'unix', 'iso', 'date', 'time'],
      builder: (BuildContext _) => const TimestampScreen(),
    ),
    UtilityDescriptor(
      id: 'json',
      name: 'JSON',
      icon: MqIcons.brackets,
      tint: const Color(0xFF8B5CF6),
      category: MqCategory.encoding,
      synonyms: <String>['pretty', 'minify', 'tree', 'parse'],
      builder: (BuildContext _) => const JSONScreen(),
    ),
    UtilityDescriptor(
      id: 'base64',
      name: 'Base64',
      icon: MqIcons.textCase,
      tint: const Color(0xFF0EA5E9),
      category: MqCategory.encoding,
      synonyms: <String>['encode', 'decode', 'b64', 'url-safe'],
      builder: (BuildContext _) => const Base64Screen(),
    ),
    UtilityDescriptor(
      id: 'color',
      name: 'Color',
      icon: MqIcons.drop,
      tint: const Color(0xFFEC4899),
      category: MqCategory.visual,
      synonyms: <String>['hex', 'rgb', 'hsl', 'oklch', 'contrast', 'wcag'],
      builder: (BuildContext _) => const ColorScreen(),
    ),
    UtilityDescriptor(
      id: 'bps',
      name: 'bps · % · decimal',
      icon: MqIcons.pct,
      tint: const Color(0xFFF59E0B),
      category: MqCategory.numeric,
      synonyms: <String>['basis points', 'percent', 'rate', 'finance'],
      builder: (BuildContext _) => const BpsScreen(),
    ),
  ];

  static UtilityDescriptor byId(String id) =>
      all.firstWhere((UtilityDescriptor u) => u.id == id);

  static List<UtilityDescriptor> byCategory(MqCategory category) =>
      all.where((UtilityDescriptor u) => u.category == category).toList();
}
