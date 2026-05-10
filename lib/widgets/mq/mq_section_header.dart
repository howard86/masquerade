import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Editorial uppercase section label, optional trailing slot, optional rule.
class MqSectionHeader extends StatelessWidget {
  const MqSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding,
    this.trailingRule = false,
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  /// When true, draws a hairline rule that fills the remaining row width
  /// after the label. Used for masthead-aligned section breaks.
  final bool trailingRule;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: MqTextStyles.sectionLabel.copyWith(
              color: tokens.colors.textSec,
            ),
          ),
          if (trailingRule) ...<Widget>[
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 0.5, color: tokens.colors.border),
            ),
          ] else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
