import 'package:flutter/cupertino.dart';

import '../state/history_controller.dart';
import '../state/theme_controller.dart';
import '../theme/mb_metrics.dart';
import '../theme/mb_theme.dart';
import '../theme/mb_typography.dart';
import '../widgets/mb/mb_button.dart';
import '../widgets/mb/mb_icons.dart';
import '../widgets/mb/mb_section_header.dart';
import '../widgets/mb/mb_segmented.dart';
import '../widgets/mb/mb_status.dart';
import '../widgets/mb/mb_surface.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mb.colors;
    final ThemeController theme = ThemeScope.of(context);
    final HistoryController history = HistoryScope.of(context);

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MBSpacing.lg,
            MBSpacing.md,
            MBSpacing.lg,
            120,
          ),
          children: <Widget>[
            Text(
              'Settings',
              style: MBTextStyles.largeTitle.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MBSpacing.xl),
            const MBSectionHeader(label: 'Appearance'),
            MBSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Theme',
                    style: MBTextStyles.headline.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MBSpacing.sm),
                  Text(
                    'Use the system setting or override per-app.',
                    style: MBTextStyles.subhead.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MBSpacing.md),
                  MBSegmented<MBThemeMode>(
                    options: const <MBThemeMode, String>{
                      MBThemeMode.system: 'System',
                      MBThemeMode.light: 'Light',
                      MBThemeMode.dark: 'Dark',
                    },
                    selected: theme.mode,
                    onChanged: theme.setMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MBSpacing.xl),
            const MBSectionHeader(label: 'Privacy'),
            MBSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(MBIcons.shield, size: 14, color: c.success),
                      const SizedBox(width: 6),
                      Text(
                        'On-device only',
                        style: MBTextStyles.headline.copyWith(color: c.textPri),
                      ),
                      const Spacer(),
                      const MBStatus(label: 'Active'),
                    ],
                  ),
                  const SizedBox(height: MBSpacing.sm),
                  Text(
                    'Magic Box never sends your inputs anywhere. All conversion happens locally.',
                    style: MBTextStyles.subhead.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MBSpacing.md),
                  Text(
                    'History retention',
                    style: MBTextStyles.footnote.copyWith(
                      color: c.textSec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: MBSpacing.sm),
                  MBSegmented<int>(
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
                  const SizedBox(height: MBSpacing.md),
                  MBButton(
                    label: 'Clear history',
                    icon: MBIcons.trash,
                    variant: MBButtonVariant.tinted,
                    destructive: true,
                    full: true,
                    onPressed: () => _confirmClear(context, history),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MBSpacing.xl),
            const MBSectionHeader(label: 'About'),
            MBSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Magic Box',
                        style: MBTextStyles.headline.copyWith(color: c.textPri),
                      ),
                      const Spacer(),
                      Text(
                        'v1.0.0',
                        style: MBTextStyles.subhead.copyWith(
                          color: c.textTer,
                          fontFamily: MBTextStyles.monoFamily,
                          fontFamilyFallback: MBTextStyles.monoFallback,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MBSpacing.xs),
                  Text(
                    'A native iOS utility toolbox for developers. Inspect, convert, format, debug — fast, on-device, copy-friendly.',
                    style: MBTextStyles.subhead.copyWith(color: c.textSec),
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
