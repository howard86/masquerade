import 'package:flutter/cupertino.dart';

import '../utility_catalog.dart';
import '../widgets/mq/mq_icons.dart';

/// System apps that open as first-class desktop windows (not tool-catalog
/// entries). Each has a fixed icon, title, and tint.
enum SystemApp { history, settings }

/// Discriminated union for what a canvas card contains: either a catalog tool
/// or a system app (History / Settings).
sealed class WindowContent {
  const WindowContent();

  /// Stable string for persistence: `'tool:<id>'` or `'system:<app>'`.
  String get persistId;

  /// Window title shown in the title bar, dock, and Window menu.
  String get title;

  /// Icon glyph for the dock and icon grid.
  IconData get icon;

  /// Tint color for the icon glyph.
  Color get tint;
}

/// A catalog tool rendered inside a desktop card.
class ToolWindow extends WindowContent {
  const ToolWindow(this.descriptor);

  final UtilityDescriptor descriptor;

  @override
  String get persistId => 'tool:${descriptor.id}';

  @override
  String get title => descriptor.name;

  @override
  IconData get icon => descriptor.icon;

  @override
  Color get tint => descriptor.tint;
}

/// A system app (History or Settings) rendered inside a desktop card.
class SystemWindow extends WindowContent {
  const SystemWindow(this.app);

  final SystemApp app;

  @override
  String get persistId => 'system:${app.name}';

  @override
  String get title => switch (app) {
    SystemApp.history => 'History',
    SystemApp.settings => 'Settings',
  };

  @override
  IconData get icon => switch (app) {
    SystemApp.history => MqIcons.history,
    SystemApp.settings => MqIcons.setting,
  };

  @override
  Color get tint => const Color(0xFF8E8E93);
}
