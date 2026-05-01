import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../state/history_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/mq/mq_status.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final HistoryController history = HistoryScope.of(context);
    final Map<String, List<HistoryEntry>> grouped = _groupByDay(
      history.entries,
    );

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MqSpacing.lg,
                MqSpacing.md,
                MqSpacing.lg,
                MqSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'History',
                      style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
                    ),
                  ),
                  if (history.entries.isNotEmpty)
                    MqButton(
                      label: 'Clear',
                      icon: MqIcons.trash,
                      variant: MqButtonVariant.glass,
                      size: MqButtonSize.sm,
                      destructive: true,
                      onPressed: () => _confirmClear(context, history),
                    ),
                ],
              ),
            ),
            Expanded(
              child: history.entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(MqIcons.history, size: 36, color: c.textTer),
                            const SizedBox(height: MqSpacing.md),
                            Text(
                              'Nothing yet',
                              style: MqTextStyles.title3.copyWith(
                                color: c.textPri,
                              ),
                            ),
                            const SizedBox(height: MqSpacing.xs),
                            Text(
                              'Your last 7 days of utility usage will appear here. On-device only.',
                              style: MqTextStyles.subhead.copyWith(
                                color: c.textSec,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        MqSpacing.lg,
                        0,
                        MqSpacing.lg,
                        120,
                      ),
                      children: <Widget>[
                        for (final MapEntry<String, List<HistoryEntry>> g
                            in grouped.entries) ...<Widget>[
                          MqSectionHeader(
                            label: g.key,
                            trailing: MqStatus(
                              label: '${g.value.length}',
                              kind: MqStatusKind.neutral,
                              showIcon: false,
                            ),
                          ),
                          for (final HistoryEntry e in g.value) ...<Widget>[
                            _HistoryRow(entry: e),
                            const SizedBox(height: MqSpacing.sm),
                          ],
                          const SizedBox(height: MqSpacing.md),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<HistoryEntry>> _groupByDay(List<HistoryEntry> entries) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final Map<String, List<HistoryEntry>> map = <String, List<HistoryEntry>>{};
    for (final HistoryEntry e in entries) {
      final DateTime d = DateTime(
        e.timestamp.year,
        e.timestamp.month,
        e.timestamp.day,
      );
      String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('EEE MMM d').format(e.timestamp);
      }
      map.putIfAbsent(label, () => <HistoryEntry>[]).add(e);
    }
    return map;
  }

  void _confirmClear(BuildContext context, HistoryController history) {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This permanently deletes all on-device entries. Cannot be undone.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              history.clear();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;
    UtilityDescriptor? u;
    try {
      u = UtilityCatalog.byId(entry.utilityId);
    } catch (_) {
      u = null;
    }
    final String displayInput = entry.sensitive
        ? '••••••••'
        : _truncate(entry.input);
    final String displayOutput = entry.sensitive
        ? '(hidden)'
        : _truncate(entry.output);
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MqRadius.md - 2),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: u?.tint ?? c.surface2,
              borderRadius: BorderRadius.circular(MqRadius.xs),
            ),
            alignment: Alignment.center,
            child: Icon(
              u?.icon ?? MqIcons.info,
              size: 14,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  u?.name ?? entry.utilityId,
                  style: MqTextStyles.subhead.copyWith(
                    color: c.textPri,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$displayInput → $displayOutput',
                  style: MqTextStyles.footnote.copyWith(
                    color: c.textSec,
                    fontFamily: MqTextStyles.monoFamily,
                    fontFamilyFallback: MqTextStyles.monoFallback,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(entry.timestamp),
            style: MqTextStyles.caption1.copyWith(
              color: c.textTer,
              fontFamily: MqTextStyles.monoFamily,
              fontFamilyFallback: MqTextStyles.monoFallback,
            ),
          ),
        ],
      ),
    );
  }

  static String _truncate(String s) =>
      s.length > 32 ? '${s.substring(0, 32)}…' : s;
}
