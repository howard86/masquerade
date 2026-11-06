import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Small outlined chip used to tag link targets (open slot, suggestion,
/// group letter). Decorative: callers own the surrounding semantics.
class LinkTag extends StatelessWidget {
  const LinkTag({super.key, required this.label, this.color});

  final String label;

  /// Border and text tint; defaults to the secondary text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? context.mq.colors.textSec;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MqRadius.xs),
        border: Border.all(color: tint, width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: MqTextStyles.monoSm.copyWith(color: tint, letterSpacing: 0.3),
      ),
    );
  }
}
