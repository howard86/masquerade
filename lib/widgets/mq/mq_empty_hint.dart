import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class MqEmptyHint extends StatelessWidget {
  const MqEmptyHint({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
      child: Text(
        label,
        style: MqTextStyles.subhead.copyWith(color: c.textTer),
      ),
    );
  }
}
