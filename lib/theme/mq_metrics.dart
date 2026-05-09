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
