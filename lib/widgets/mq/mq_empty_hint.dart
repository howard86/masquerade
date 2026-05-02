import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Tertiary-text hint shown in detail-screen output slots when there is no
/// input/result yet.
class MqEmptyHint extends StatelessWidget {
  const MqEmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
      child: Text(text, style: MqTextStyles.subhead.copyWith(color: c.textTer)),
    );
  }
}
