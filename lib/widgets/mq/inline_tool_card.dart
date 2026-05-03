import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';

/// A tool selector that renders chip-styled when collapsed and reveals the
/// tool body inline when [expanded].
///
/// Visual model: each tool is a pill-shaped tappable chip — the same shape
/// used by the hero detection chips. Selecting (tapping) the chip flips its
/// accent and unfurls its body below the same chip; tapping the selected
/// chip again collapses it. Body state (controllers, recorder) lives only
/// while [expanded] is true.
class InlineToolCard extends StatelessWidget {
  const InlineToolCard({
    super.key,
    required this.descriptor,
    required this.expanded,
    required this.onToggle,
    required this.bodyBuilder,
  });

  final UtilityDescriptor descriptor;
  final bool expanded;
  final VoidCallback onToggle;
  final WidgetBuilder bodyBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color chipBg = expanded ? c.accentBg : c.surface2;
    final Color chipBorder = expanded
        ? c.accent.withValues(alpha: 0.25)
        : c.border;
    final Color textColor = expanded ? c.accentInk : c.textPri;

    return Semantics(
      button: true,
      expanded: expanded,
      label: descriptor.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(MqRadius.pill),
                border: Border.all(color: chipBorder, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(descriptor.icon, size: 14, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    descriptor.name,
                    style: MqTextStyles.subhead.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: MqMotion.normal,
              curve: MqMotion.standard,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, MqSpacing.md, 0, 0),
                      child: Builder(builder: bodyBuilder),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
