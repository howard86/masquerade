import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../state/history_controller.dart';
import '../theme/mb_metrics.dart';
import '../theme/mb_theme.dart';
import '../theme/mb_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mb/mb_button.dart';
import '../widgets/mb/mb_icons.dart';
import '../widgets/mb/mb_section_header.dart';
import '../widgets/mb/mb_status.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mb.colors;
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
                MBSpacing.lg,
                MBSpacing.md,
                MBSpacing.lg,
                MBSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'History',
                      style: MBTextStyles.largeTitle.copyWith(color: c.textPri),
                    ),
                  ),
                  if (history.entries.isNotEmpty)
                    MBButton(
                      label: 'Clear',
                      icon: MBIcons.trash,
                      variant: MBButtonVariant.glass,
                      size: MBButtonSize.sm,
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
                          horizontal: MBSpacing.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(MBIcons.history, size: 36, color: c.textTer),
                            const SizedBox(height: MBSpacing.md),
                            Text(
                              'Nothing yet',
                              style: MBTextStyles.title3.copyWith(
                                color: c.textPri,
                              ),
                            ),
                            const SizedBox(height: MBSpacing.xs),
                            Text(
                              'Your last 7 days of utility usage will appear here. On-device only.',
                              style: MBTextStyles.subhead.copyWith(
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
                        MBSpacing.lg,
                        0,
                        MBSpacing.lg,
                        120,
                      ),
                      children: <Widget>[
                        for (final MapEntry<String, List<HistoryEntry>> g
                            in grouped.entries) ...<Widget>[
                          MBSectionHeader(
                            label: g.key,
                            trailing: MBStatus(
                              label: '${g.value.length}',
                              kind: MBStatusKind.neutral,
                              showIcon: false,
                            ),
                          ),
                          for (final HistoryEntry e in g.value) ...<Widget>[
                            _HistoryRow(entry: e),
                            const SizedBox(height: MBSpacing.sm),
                          ],
                          const SizedBox(height: MBSpacing.md),
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
    final tokens = context.mb;
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
      padding: const EdgeInsets.all(MBSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MBRadius.md - 2),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: u?.tint ?? c.surface2,
              borderRadius: BorderRadius.circular(MBRadius.xs),
            ),
            alignment: Alignment.center,
            child: Icon(
              u?.icon ?? MBIcons.info,
              size: 14,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(width: MBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  u?.name ?? entry.utilityId,
                  style: MBTextStyles.subhead.copyWith(
                    color: c.textPri,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$displayInput → $displayOutput',
                  style: MBTextStyles.footnote.copyWith(
                    color: c.textSec,
                    fontFamily: MBTextStyles.monoFamily,
                    fontFamilyFallback: MBTextStyles.monoFallback,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(entry.timestamp),
            style: MBTextStyles.caption1.copyWith(
              color: c.textTer,
              fontFamily: MBTextStyles.monoFamily,
              fontFamilyFallback: MBTextStyles.monoFallback,
            ),
          ),
        ],
      ),
    );
  }

  static String _truncate(String s) =>
      s.length > 32 ? '${s.substring(0, 32)}…' : s;
}
