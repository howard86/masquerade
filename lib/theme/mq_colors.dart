import 'package:flutter/painting.dart';

/// Masquerade editorial palette. Warm cream + oxblood (light), espresso +
/// lamplight gold (dark). Mono syntax fields reference status tokens so a
/// code cell renders with the same vocabulary as a status badge.
class MqColors {
  const MqColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.textPri,
    required this.textSec,
    required this.textTer,
    required this.textInverse,
    required this.onTint,
    required this.accent,
    required this.accentInk,
    required this.accentBg,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.monoBg,
    required this.monoText,
    required this.monoComment,
    required this.monoString,
    required this.monoNumber,
    required this.monoKey,
    required this.monoPunc,
    required this.shadow,
    required this.shadowLg,
  });

  factory MqColors.light() => const MqColors(
    bg: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFDF8),
    surface2: Color(0xFFF5F1E8),
    surface3: Color(0xFFF1ECE2),
    border: Color(0x1F1B1813),
    borderStrong: Color(0x3D1B1813),
    textPri: Color(0xFF1B1813),
    textSec: Color(0xFF5C544A),
    textTer: Color(0xFF9A8F82),
    textInverse: Color(0xFFFFFDF8),
    onTint: Color(0xFFFFFDF8),
    accent: Color(0xFF8B2635),
    accentInk: Color(0xFF5E1923),
    accentBg: Color(0x1A8B2635),
    success: Color(0xFF2D5F3F),
    successBg: Color(0x1F2D5F3F),
    warning: Color(0xFFB07A1F),
    warningBg: Color(0x1FB07A1F),
    danger: Color(0xFF6E1F1F),
    dangerBg: Color(0x1F6E1F1F),
    info: Color(0xFF2D4A7A),
    monoBg: Color(0xFFF1ECE2),
    monoText: Color(0xFF1B1813),
    monoComment: Color(0xFF5C544A),
    monoString: Color(0xFF2D5F3F),
    monoNumber: Color(0xFFB07A1F),
    monoKey: Color(0xFF2D4A7A),
    monoPunc: Color(0xFF5C544A),
    shadow: <BoxShadow>[
      BoxShadow(color: Color(0x141B1813), blurRadius: 12, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x0A1B1813), blurRadius: 2, offset: Offset(0, 1)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(
        color: Color(0x241B1813),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x141B1813), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  factory MqColors.dark() => const MqColors(
    bg: Color(0xFF14110D),
    surface: Color(0xFF1C1814),
    surface2: Color(0xFF241F19),
    surface3: Color(0xFF2B241B),
    border: Color(0x24F2EBDC),
    borderStrong: Color(0x47F2EBDC),
    textPri: Color(0xFFF2EBDC),
    textSec: Color(0xFFA89B86),
    textTer: Color(0xFF6E6354),
    textInverse: Color(0xFF14110D),
    onTint: Color(0xFF14110D),
    accent: Color(0xFFE0B872),
    accentInk: Color(0xFFF0D9A6),
    accentBg: Color(0x24E0B872),
    success: Color(0xFF7CB893),
    successBg: Color(0x247CB893),
    warning: Color(0xFFE0B872),
    warningBg: Color(0x24E0B872),
    danger: Color(0xFFE08A8A),
    dangerBg: Color(0x24E08A8A),
    info: Color(0xFF8FB3E8),
    monoBg: Color(0xFF2B241B),
    monoText: Color(0xFFF2EBDC),
    monoComment: Color(0xFFA89B86),
    monoString: Color(0xFF7CB893),
    monoNumber: Color(0xFFE0B872),
    monoKey: Color(0xFF8FB3E8),
    monoPunc: Color(0xFFA89B86),
    shadow: <BoxShadow>[
      BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color textPri;
  final Color textSec;
  final Color textTer;
  final Color textInverse;

  /// Foreground for filled accent surfaces (primary buttons, status pills with
  /// solid fills). Resolves to the page background tone in each mode so an
  /// oxblood/gold fill carries cream/espresso ink — the editorial inverse,
  /// not stark white.
  final Color onTint;
  final Color accent;
  final Color accentInk;
  final Color accentBg;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color monoBg;
  final Color monoText;
  final Color monoComment;
  final Color monoString;
  final Color monoNumber;
  final Color monoKey;
  final Color monoPunc;

  /// Reserved for floating modal/toast surfaces only. Cards use a hairline
  /// border instead.
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowLg;

  static MqColors lerp(MqColors a, MqColors b, double t) => MqColors(
    bg: Color.lerp(a.bg, b.bg, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    surface2: Color.lerp(a.surface2, b.surface2, t)!,
    surface3: Color.lerp(a.surface3, b.surface3, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
    textPri: Color.lerp(a.textPri, b.textPri, t)!,
    textSec: Color.lerp(a.textSec, b.textSec, t)!,
    textTer: Color.lerp(a.textTer, b.textTer, t)!,
    textInverse: Color.lerp(a.textInverse, b.textInverse, t)!,
    onTint: Color.lerp(a.onTint, b.onTint, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    accentInk: Color.lerp(a.accentInk, b.accentInk, t)!,
    accentBg: Color.lerp(a.accentBg, b.accentBg, t)!,
    success: Color.lerp(a.success, b.success, t)!,
    successBg: Color.lerp(a.successBg, b.successBg, t)!,
    warning: Color.lerp(a.warning, b.warning, t)!,
    warningBg: Color.lerp(a.warningBg, b.warningBg, t)!,
    danger: Color.lerp(a.danger, b.danger, t)!,
    dangerBg: Color.lerp(a.dangerBg, b.dangerBg, t)!,
    info: Color.lerp(a.info, b.info, t)!,
    monoBg: Color.lerp(a.monoBg, b.monoBg, t)!,
    monoText: Color.lerp(a.monoText, b.monoText, t)!,
    monoComment: Color.lerp(a.monoComment, b.monoComment, t)!,
    monoString: Color.lerp(a.monoString, b.monoString, t)!,
    monoNumber: Color.lerp(a.monoNumber, b.monoNumber, t)!,
    monoKey: Color.lerp(a.monoKey, b.monoKey, t)!,
    monoPunc: Color.lerp(a.monoPunc, b.monoPunc, t)!,
    shadow: t < 0.5 ? a.shadow : b.shadow,
    shadowLg: t < 0.5 ? a.shadowLg : b.shadowLg,
  );
}
