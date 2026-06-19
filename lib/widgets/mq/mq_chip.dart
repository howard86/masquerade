import 'package:flutter/services.dart';
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
    this.selected = false,
    this.mono = true,
    this.onTap,
  });

  final String label;
  final IconData? icon;

  /// Decorative emphasis only. Paints the accent background/border/text.
  /// Does NOT claim the selected a11y state — use [selected] for toggles.
  final bool accent;

  /// Toggle/selection state. Drives `Semantics(selected:)` so screen readers
  /// announce the on/off choice, and also turns on the accent visual (a
  /// selected chip looks accented). Leave `false` on decorative/action chips
  /// so they don't wrongly announce "selected".
  final bool selected;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;
    // Either a deliberate selection or decorative accent paints the emphasis.
    final bool emphasized = selected || accent;
    final TextStyle base = MqTextStyles.caption1.copyWith(
      fontFamily: mono ? MqTextStyles.monoFamily : MqTextStyles.sansFamily,
      fontFamilyFallback: mono
          ? MqTextStyles.monoFallback
          : MqTextStyles.sansFallback,
      fontWeight: FontWeight.w500,
      color: emphasized ? c.accent : c.textPri,
    );
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? c.accentBg : const Color(0x00000000),
        borderRadius: BorderRadius.circular(MqRadius.pill),
        border: Border.all(color: emphasized ? c.accent : c.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: emphasized ? c.accent : c.textSec),
            const SizedBox(width: 6),
          ],
          // Loose Flexible: short chips size to content; a chip whose label is
          // wider than the available line (e.g. at large Dynamic Type) shrinks
          // and ellipsizes instead of overflowing. All call sites give the chip
          // a width-bounded parent (Wrap / stretch column), so this is safe.
          Flexible(
            child: Text(
              label,
              style: base,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    // Tappable chips are buttons: announce the role + label so screen readers
    // describe them as such across every call site. `selected` (NOT `accent`)
    // drives the toggle/selected state — decorative-accent action chips leave
    // it `false` so they don't wrongly announce "selected".
    // `excludeSemantics` keeps the announcement to a single node (the explicit
    // label) instead of also reading the inner Text.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: chip,
      ),
    );
  }
}
