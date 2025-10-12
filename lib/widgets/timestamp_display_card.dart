import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:masquerade/widgets/timestamp_row.dart';

class TimestampDisplayCard extends StatelessWidget {
  const TimestampDisplayCard({super.key, required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date & Time',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle
                  .copyWith(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TimestampRow(
              label: 'UTC Time:',
              value: DateFormat(
                'yyyy-MM-dd HH:mm:ss',
              ).format(timestamp.toUtc()),
            ),
            const SizedBox(height: 12),
            TimestampRow(
              label: 'Local Time:',
              value: DateFormat(
                'yyyy-MM-dd HH:mm:ss',
              ).format(timestamp.toLocal()),
            ),
            const SizedBox(height: 12),
            TimestampRow(
              label: 'Unix Timestamp (seconds):',
              value: (timestamp.millisecondsSinceEpoch / 1000)
                  .round()
                  .toString(),
            ),
            const SizedBox(height: 12),
            TimestampRow(
              label: 'Unix Timestamp (milliseconds):',
              value: timestamp.millisecondsSinceEpoch.toString(),
            ),
          ],
        ),
      ),
    );
  }
}
