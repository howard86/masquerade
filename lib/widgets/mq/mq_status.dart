import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

enum MqStatusKind { success, warning, danger, info, neutral }

/// Editorial status pill — tinted bg + matching ink. Always pairs with a
/// glyph + label to stay readable when the warning hue overlaps the gold
/// accent in dark mode.
class MqStatus extends StatelessWidget {
  const MqStatus({
    super.key,
    required this.label,
    this.kind = MqStatusKind.success,
    this.showIcon = true,
  });

  final String label;
  final MqStatusKind kind;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final ({Color bg, Color fg, IconData? icon}) style = switch (kind) {
      MqStatusKind.success => (
        bg: c.successBg,
        fg: c.success,
        icon: MqIcons.check,
      ),
      MqStatusKind.warning => (
        bg: c.warningBg,
        fg: c.warning,
        icon: MqIcons.warn,
      ),
      MqStatusKind.danger => (bg: c.dangerBg, fg: c.danger, icon: MqIcons.warn),
      MqStatusKind.info => (bg: c.accentBg, fg: c.accent, icon: MqIcons.info),
      MqStatusKind.neutral => (bg: c.surface2, fg: c.textSec, icon: null),
    };
    // Errors and warnings must announce as they appear — every tool routes its
    // parse failures through this pill, so a live region here covers them all.
    final bool isLive =
        kind == MqStatusKind.danger || kind == MqStatusKind.warning;
    return Semantics(
      liveRegion: isLive,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(MqRadius.pill),
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
              style: MqTextStyles.caption2.copyWith(
                color: style.fg,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
