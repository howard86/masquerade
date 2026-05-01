import 'package:flutter/cupertino.dart';

import '../state/history_controller.dart';
import '../state/theme_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/mq/mq_segmented.dart';
import '../widgets/mq/mq_status.dart';
import '../widgets/mq/mq_surface.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final ThemeController theme = ThemeScope.of(context);
    final HistoryController history = HistoryScope.of(context);

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg,
            MqSpacing.md,
            MqSpacing.lg,
            120,
          ),
          children: <Widget>[
            Text(
              'Settings',
              style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.xl),
            const MqSectionHeader(label: 'Appearance'),
            MqSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Theme',
                    style: MqTextStyles.headline.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  Text(
                    'Use the system setting or override per-app.',
                    style: MqTextStyles.subhead.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqSegmented<MqThemeMode>(
                    options: const <MqThemeMode, String>{
                      MqThemeMode.system: 'System',
                      MqThemeMode.light: 'Light',
                      MqThemeMode.dark: 'Dark',
                    },
                    selected: theme.mode,
                    onChanged: theme.setMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MqSpacing.xl),
            const MqSectionHeader(label: 'Privacy'),
            MqSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(MqIcons.shield, size: 14, color: c.success),
                      const SizedBox(width: 6),
                      Text(
                        'On-device only',
                        style: MqTextStyles.headline.copyWith(color: c.textPri),
                      ),
                      const Spacer(),
                      const MqStatus(label: 'Active'),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  Text(
                    'Masquerade never sends your inputs anywhere. All conversion happens locally.',
                    style: MqTextStyles.subhead.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  Text(
                    'History retention',
                    style: MqTextStyles.footnote.copyWith(
                      color: c.textSec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  MqSegmented<int>(
                    options: const <int, String>{
                      1: '1 day',
                      7: '7 days',
                      30: '30 days',
                      0: 'Off',
                    },
                    selected: history.retention.inDays,
                    onChanged: (int days) =>
                        history.setRetention(Duration(days: days)),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqButton(
                    label: 'Clear history',
                    icon: MqIcons.trash,
                    variant: MqButtonVariant.tinted,
                    destructive: true,
                    full: true,
                    onPressed: () => _confirmClear(context, history),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MqSpacing.xl),
            const MqSectionHeader(label: 'About'),
            MqSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Masquerade',
                        style: MqTextStyles.headline.copyWith(color: c.textPri),
                      ),
                      const Spacer(),
                      Text(
                        'v1.0.0',
                        style: MqTextStyles.subhead.copyWith(
                          color: c.textTer,
                          fontFamily: MqTextStyles.monoFamily,
                          fontFamilyFallback: MqTextStyles.monoFallback,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.xs),
                  Text(
                    'A native iOS utility toolbox for developers. Inspect, convert, format, debug — fast, on-device, copy-friendly.',
                    style: MqTextStyles.subhead.copyWith(color: c.textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, HistoryController history) {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('Permanently deletes all on-device entries.'),
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
