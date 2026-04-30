import 'package:flutter/widgets.dart';

import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';

/// Uppercase section label, optional trailing slot.
class MBSectionHeader extends StatelessWidget {
  const MBSectionHeader({
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
    final tokens = context.mb;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MBTextStyles.sectionLabel.copyWith(
                color: tokens.colors.textSec,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
