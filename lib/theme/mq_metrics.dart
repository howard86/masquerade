import 'package:flutter/animation.dart';

/// Spacing scale (logical px). Mirrors `MQ_TOKENS.spacing`.
class MqSpacing {
  const MqSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radius scale. Mirrors `MQ_TOKENS.radius`.
class MqRadius {
  const MqRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double pill = 9999;
}

/// Layout constants that depend on chrome (tab bar, nav bar). Logical px.
class MqLayout {
  const MqLayout._();

  /// Bottom padding for scrollable tab content so the last item clears the
  /// translucent CupertinoTabBar (49pt nominal height + safe-area inset +
  /// breathing room). Used by every screen mounted inside RootTabScaffold.
  static const double tabBarClearance = 96;

  /// Minimum viewport width (logical px) at which the web desktop shell and
  /// the desktop↔mobile toggle become available. Below this, web falls back
  /// to the mobile UI with no toggle.
  static const double desktopBreakpoint = 900;

  /// Fixed width of the desktop shell's left navigation sidebar.
  static const double sidebarWidth = 248;

  /// Max width of the whole desktop shell (sidebar + content). Beyond this the
  /// shell stops growing and centers on the page background, so the app reads
  /// as a tidy window instead of stretching adrift across an ultrawide monitor.
  static const double desktopShellMaxWidth = 1440;

  /// Max width of the desktop Home content (tool grid) before it stops growing
  /// and centers — keeps tiles from stretching on ultrawide monitors.
  static const double desktopContentMaxWidth = 1100;

  /// Max width for prose-style desktop panes (History, Settings, tool bodies)
  /// so single-column lists stay comfortably readable.
  static const double readableMaxWidth = 720;

  /// Target max width of a Home tool tile; the grid derives its column count
  /// from this so phones get 2 columns and the desktop pane gets 3–4.
  static const double tileMaxExtent = 260;
}

/// Editorial reading-pace motion. Asymmetric reveal/dismiss — no overshoot.
class MqMotion {
  const MqMotion._();
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);

  /// Reveal curve — slight ease-out, used for expand/in transitions.
  static const Curve reveal = Cubic(0.2, 0.6, 0.2, 1.0);

  /// Dismiss curve — symmetric ease, used for collapse/out transitions.
  static const Curve dismiss = Cubic(0.4, 0.0, 0.6, 1.0);

  /// Linear cascade between hero text lines (60ms steps).
  static const Curve stagger = Curves.linear;
  static const Duration staggerStep = Duration(milliseconds: 60);
}
