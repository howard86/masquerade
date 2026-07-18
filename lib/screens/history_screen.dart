import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../state/history_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../utils/copy_util.dart';
import '../utils/sensitive_data_policy.dart';
import 'detail/tool_detail_route.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/mq/mq_status.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.title = 'History', this.navigationBar});

  final String title;
  final ObstructingPreferredSizeWidget? navigationBar;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: navigationBar,
      child: SafeArea(bottom: false, child: HistoryBody(title: title)),
    );
  }
}

/// The inner content of the History screen, reusable without a scaffold.
/// Used directly by the desktop window manager.
class HistoryBody extends StatefulWidget {
  const HistoryBody({super.key, this.title = 'History'});

  final String title;

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final HistoryController history = HistoryScope.of(context);
    final List<HistoryEntry> filtered = history.search(
      _query,
      toolName: (HistoryEntry entry) => _toolName(entry.utilityId),
      dateLabel: (HistoryEntry entry) => <String>[
        _dayLabel(entry.timestamp),
        DateFormat('yyyy-MM-dd').format(entry.timestamp),
        DateFormat('EEEE MMMM d').format(entry.timestamp),
        DateFormat('HH:mm').format(entry.timestamp),
      ].join(' '),
    );
    final List<HistoryEntry> pinned = filtered
        .where((HistoryEntry entry) => entry.pinned)
        .toList();
    final Map<String, List<HistoryEntry>> grouped = _groupByDay(
      filtered.where((HistoryEntry entry) => !entry.pinned).toList(),
    );

    return Column(
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
                  widget.title,
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
                          style: MqTextStyles.title3.copyWith(color: c.textPri),
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
                    MqSpacing.lg,
                  ),
                  children: <Widget>[
                    SizedBox(
                      height: 44,
                      child: CupertinoSearchTextField(
                        placeholder: 'Search tool, value, or date',
                        onChanged: (String value) =>
                            setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(height: MqSpacing.md),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: MqSpacing.xl,
                        ),
                        child: Text(
                          'No matching activity',
                          style: MqTextStyles.subhead.copyWith(
                            color: c.textSec,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (pinned.isNotEmpty) ...<Widget>[
                      MqSectionHeader(
                        label: 'PINNED',
                        trailing: MqStatus(
                          label: '${pinned.length}',
                          kind: MqStatusKind.neutral,
                          showIcon: false,
                        ),
                      ),
                      for (final HistoryEntry entry in pinned) ...<Widget>[
                        _HistoryRow(entry: entry, history: history),
                        const SizedBox(height: MqSpacing.sm),
                      ],
                      const SizedBox(height: MqSpacing.md),
                    ],
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
                        _HistoryRow(entry: e, history: history),
                        const SizedBox(height: MqSpacing.sm),
                      ],
                      const SizedBox(height: MqSpacing.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

Map<String, List<HistoryEntry>> _groupByDay(List<HistoryEntry> entries) {
  final Map<String, List<HistoryEntry>> map = <String, List<HistoryEntry>>{};
  for (final HistoryEntry e in entries) {
    map.putIfAbsent(_dayLabel(e.timestamp), () => <HistoryEntry>[]).add(e);
  }
  return map;
}

String _dayLabel(DateTime timestamp) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));
  final DateTime date = DateTime(
    timestamp.year,
    timestamp.month,
    timestamp.day,
  );
  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';
  return DateFormat('EEE MMM d').format(timestamp);
}

String _toolName(String utilityId) {
  try {
    return UtilityCatalog.byId(utilityId).name;
  } catch (_) {
    return utilityId;
  }
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.history});
  final HistoryEntry entry;
  final HistoryController history;

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
    final String displayInput = SensitiveDataPolicy.safePreview(
      entry.input,
      max: _truncateAt,
      utilityId: entry.utilityId,
      sensitive: entry.sensitive,
    );
    final String displayOutput = SensitiveDataPolicy.safePreview(
      entry.output,
      max: _truncateAt,
      utilityId: entry.utilityId,
      sensitive: entry.sensitive,
    );
    final String toolName = u?.name ?? entry.utilityId;
    final bool protected = entry.protected;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MqRadius.md),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            enabled: u != null && !protected,
            label: 'Reopen $toolName with saved input',
            excludeSemantics: true,
            child: CupertinoButton(
              padding: const EdgeInsets.all(MqSpacing.md),
              minimumSize: const Size.fromHeight(44),
              borderRadius: BorderRadius.circular(MqRadius.md),
              onPressed: u == null || protected
                  ? null
                  : () => ToolDetailRoute.push(context, u!, seed: entry.input),
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
                      color: c.onTint,
                    ),
                  ),
                  const SizedBox(width: MqSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          toolName,
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
                  const SizedBox(width: MqSpacing.sm),
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
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _HistoryAction(
                  label: 'Copy $toolName output',
                  icon: MqIcons.copy,
                  onPressed: protected
                      ? null
                      : () => CopyToClipboardUtil.copyToClipboard(
                          context,
                          entry.output,
                        ),
                ),
                _HistoryAction(
                  label: entry.pinned
                      ? 'Unpin $toolName entry'
                      : 'Pin $toolName entry',
                  icon: MqIcons.star,
                  active: entry.pinned,
                  onPressed: protected
                      ? null
                      : () => history.togglePinned(entry),
                ),
                _HistoryAction(
                  label: 'Delete $toolName entry',
                  icon: MqIcons.trash,
                  destructive: true,
                  onPressed: () => history.delete(entry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visible length cap for the input/output preview line. Anything longer
  /// gets a single ellipsis so the row stays one line at any device width.
  static const int _truncateAt = 32;
}

class _HistoryAction extends StatelessWidget {
  const _HistoryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 18,
          color: destructive
              ? c.danger
              : active
              ? c.accent
              : c.textSec,
        ),
      ),
    );
  }
}
