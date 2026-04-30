import 'package:flutter/widgets.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import 'mb_icons.dart';

enum MBStatusKind { success, warning, danger, info, neutral }

class MBStatus extends StatelessWidget {
  const MBStatus({
    super.key,
    required this.label,
    this.kind = MBStatusKind.success,
    this.showIcon = true,
  });

  final String label;
  final MBStatusKind kind;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.mb.colors;
    final ({Color bg, Color fg, IconData? icon}) style = switch (kind) {
      MBStatusKind.success => (
        bg: c.successBg,
        fg: c.success,
        icon: MBIcons.check,
      ),
      MBStatusKind.warning => (
        bg: c.warningBg,
        fg: c.warning,
        icon: MBIcons.warn,
      ),
      MBStatusKind.danger => (bg: c.dangerBg, fg: c.danger, icon: MBIcons.warn),
      MBStatusKind.info => (
        bg: c.accentBg,
        fg: c.accentInk,
        icon: MBIcons.info,
      ),
      MBStatusKind.neutral => (bg: c.surface2, fg: c.textSec, icon: null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(MBRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon && style.icon != null) ...<Widget>[
            Icon(style.icon, size: 11, color: style.fg),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: MBTextStyles.caption2.copyWith(
              color: style.fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
