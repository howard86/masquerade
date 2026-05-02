import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class MqChip extends StatelessWidget {
  const MqChip({
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
    final tokens = context.mq;
    final c = tokens.colors;
    final TextStyle base =
        (mono ? MqTextStyles.caption1 : MqTextStyles.caption1).copyWith(
          fontFamily: mono ? MqTextStyles.monoFamily : MqTextStyles.sansFamily,
          fontFamilyFallback: mono
              ? MqTextStyles.monoFallback
              : MqTextStyles.sansFallback,
          fontWeight: FontWeight.w500,
          color: accent ? c.accentInk : c.textPri,
        );
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? c.accentBg : c.surface2,
        borderRadius: BorderRadius.circular(MqRadius.pill),
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
