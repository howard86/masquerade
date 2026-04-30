import 'package:flutter/widgets.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';

class MBChip extends StatelessWidget {
  const MBChip({
    super.key,
    required this.label,
    this.icon,
    this.accent = false,
    this.mono = true,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool accent;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    final c = tokens.colors;
    final TextStyle base =
        (mono ? MBTextStyles.caption1 : MBTextStyles.caption1).copyWith(
          fontFamily: mono ? MBTextStyles.monoFamily : MBTextStyles.sansFamily,
          fontFamilyFallback: mono
              ? MBTextStyles.monoFallback
              : MBTextStyles.sansFallback,
          fontWeight: FontWeight.w500,
          color: accent ? c.accentInk : c.textPri,
        );
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? c.accentBg : c.surface2,
        borderRadius: BorderRadius.circular(MBRadius.pill),
        border: Border.all(
          color: accent ? c.accent.withValues(alpha: 0.25) : c.border,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: accent ? c.accentInk : c.textSec),
            const SizedBox(width: 6),
          ],
          Text(label, style: base),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: chip,
    );
  }
}
