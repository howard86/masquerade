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

/// Motion durations + curves. Mirrors `MQ_TOKENS.motion`.
class MqMotion {
  const MqMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration spring = Duration(milliseconds: 420);

  /// Standard ease — cubic-bezier(.2,.7,.3,1).
  static const Curve standard = Cubic(0.2, 0.7, 0.3, 1.0);

  /// Spring overshoot — cubic-bezier(.34,1.56,.64,1).
  static const Curve springCurve = Cubic(0.34, 1.56, 0.64, 1.0);
}
