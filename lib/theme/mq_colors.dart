import 'package:flutter/painting.dart';

/// Masquerade color tokens. Cool greys + electric cyan accent.
/// Mirrors `tokens.jsx` exactly. Both modes are first-class.
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
    bg: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF0F3),
    surface3: Color(0xFFE2E6EB),
    border: Color(0x140F172A),
    borderStrong: Color(0x240F172A),
    textPri: Color(0xFF0B1220),
    textSec: Color(0xFF475569),
    textTer: Color(0xFF94A3B8),
    textInverse: Color(0xFFFFFFFF),
    onTint: Color(0xFFFFFFFF),
    accent: Color(0xFF00B8C4),
    accentInk: Color(0xFF006B72),
    accentBg: Color(0x1A00B8C4),
    success: Color(0xFF0E9F6E),
    successBg: Color(0x1A0E9F6E),
    warning: Color(0xFFC2750B),
    warningBg: Color(0x1AC2750B),
    danger: Color(0xFFD63B3B),
    dangerBg: Color(0x1AD63B3B),
    info: Color(0xFF3B6DD6),
    monoBg: Color(0xFFF1F4F7),
    monoText: Color(0xFF0B1220),
    monoComment: Color(0xFF94A3B8),
    monoString: Color(0xFF0E7C66),
    monoNumber: Color(0xFFA04400),
    monoKey: Color(0xFF1F4FB8),
    monoPunc: Color(0xFF475569),
    shadow: <BoxShadow>[
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(color: Color(0x1A0F172A), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  factory MqColors.dark() => const MqColors(
    bg: Color(0xFF0A0E14),
    surface: Color(0xFF121821),
    surface2: Color(0xFF1A222D),
    surface3: Color(0xFF232C39),
    border: Color(0x1F94A3B8),
    borderStrong: Color(0x3894A3B8),
    textPri: Color(0xFFE6EDF5),
    textSec: Color(0xFF94A3B8),
    textTer: Color(0xFF64748B),
    textInverse: Color(0xFF0A0E14),
    onTint: Color(0xFFFFFFFF),
    accent: Color(0xFF22D3EE),
    accentInk: Color(0xFF67E8F5),
    accentBg: Color(0x2422D3EE),
    success: Color(0xFF34D399),
    successBg: Color(0x2434D399),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0x24F59E0B),
    danger: Color(0xFFF87171),
    dangerBg: Color(0x24F87171),
    info: Color(0xFF60A5FA),
    monoBg: Color(0xFF0E141B),
    monoText: Color(0xFFE6EDF5),
    monoComment: Color(0xFF64748B),
    monoString: Color(0xFF5EEAD4),
    monoNumber: Color(0xFFFCA15A),
    monoKey: Color(0xFF7DA8FF),
    monoPunc: Color(0xFF94A3B8),
    shadow: <BoxShadow>[
      BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
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

  /// Foreground for high-saturation tinted surfaces (utility tile icons,
  /// history-row badges). Always white in both modes — the tints are brand
  /// colors picked for white-on-color contrast, not theme background.
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
