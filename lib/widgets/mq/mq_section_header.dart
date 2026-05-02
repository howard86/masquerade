import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Uppercase section label, optional trailing slot.
class MqSectionHeader extends StatelessWidget {
  const MqSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding,
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MqTextStyles.sectionLabel.copyWith(
                color: tokens.colors.textSec,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
