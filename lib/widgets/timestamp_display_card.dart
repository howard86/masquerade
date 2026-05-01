import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import 'mq/mq_mono_cell.dart';
import 'mq/mq_surface.dart';

/// Card displaying a timestamp in all common forms.
///
/// Label strings ("Date & Time", "UTC Time:", "Local Time:",
/// "Unix Timestamp (seconds):", "Unix Timestamp (milliseconds):") are pinned
/// by `test/widget_test.dart` and must not change.
class TimestampDisplayCard extends StatelessWidget {
  const TimestampDisplayCard({super.key, required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String utc = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(timestamp.toUtc());
    final String local = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(timestamp.toLocal());
    final int secs = (timestamp.millisecondsSinceEpoch / 1000).round();
    final int ms = timestamp.millisecondsSinceEpoch;

    return MqSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Date & Time',
            style: MqTextStyles.title3.copyWith(color: c.textPri),
          ),
          const SizedBox(height: MqSpacing.md),
          MqMonoCell(label: 'UTC Time:', value: utc),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Local Time:', value: local),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Unix Timestamp (seconds):', value: '$secs'),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Unix Timestamp (milliseconds):', value: '$ms'),
        ],
      ),
    );
  }
}
