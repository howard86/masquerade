import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

import '../state/history_controller.dart';
import '../state/theme_controller.dart';
import '../state/view_mode_controller.dart';
import '../state/wallpaper_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utils/shell_layout.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_section_header.dart';
import '../widgets/mq/mq_segmented.dart';
import '../widgets/mq/mq_status.dart';
import '../widgets/mq/mq_surface.dart';

/// Cached once at first access — `PackageInfo.fromPlatform()` does a
/// platform-channel hop, so we don't re-fire it on every Settings rebuild.
final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isWebOverride});

  /// See `MyApp.isWebOverride`. Null in production → reads [kIsWeb]. Gates the
  /// desktop↔mobile "Layout" row, which is only meaningful on wide web.
  final bool? isWebOverride;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: SettingsBody(isWebOverride: isWebOverride),
      ),
    );
  }
}

/// The inner content of the Settings screen, reusable without a scaffold.
/// Used directly by the desktop window manager.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, this.isWebOverride});

  final bool? isWebOverride;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final ThemeController theme = ThemeScope.of(context);
    final HistoryController history = HistoryScope.of(context);
    final ViewModeController viewMode = ViewModeScope.of(context);
    final bool showViewToggle = toggleAvailable(
      isWeb: isWebOverride ?? kIsWeb,
      width: MediaQuery.sizeOf(context).width,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.md,
        MqSpacing.lg,
        MqSpacing.lg,
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
        if (showViewToggle) ...<Widget>[
          const SizedBox(height: MqSpacing.xl),
          const MqSectionHeader(label: 'Desktop Wallpaper'),
          MqSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Wallpaper style',
                  style: MqTextStyles.headline.copyWith(color: c.textPri),
                ),
                const SizedBox(height: MqSpacing.sm),
                Text(
                  'Choose a generative or solid background style for your desktop.',
                  style: MqTextStyles.subhead.copyWith(color: c.textSec),
                ),
                const SizedBox(height: MqSpacing.md),
                ListenableBuilder(
                  listenable: WallpaperScope.of(context),
                  builder: (context, _) {
                    final WallpaperController wp = WallpaperScope.of(context);
                    return MqSegmented<MqWallpaperType>(
                      options: const <MqWallpaperType, String>{
                        MqWallpaperType.auroraEspresso: 'Aurora',
                        MqWallpaperType.parchmentMinimalist: 'Minimalist',
                        MqWallpaperType.cyberGlass: 'Cyber',
                        MqWallpaperType.slateSolid: 'Slate',
                      },
                      selected: wp.type,
                      onChanged: wp.setType,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (showViewToggle) ...<Widget>[
          const SizedBox(height: MqSpacing.xl),
          const MqSectionHeader(label: 'Layout'),
          MqSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'View',
                  style: MqTextStyles.headline.copyWith(color: c.textPri),
                ),
                const SizedBox(height: MqSpacing.sm),
                Text(
                  'Use the full desktop layout or the mobile preview.',
                  style: MqTextStyles.subhead.copyWith(color: c.textSec),
                ),
                const SizedBox(height: MqSpacing.md),
                MqSegmented<MqViewMode>(
                  options: const <MqViewMode, String>{
                    MqViewMode.desktop: 'Desktop',
                    MqViewMode.mobile: 'Mobile',
                  },
                  selected: viewMode.mode,
                  onChanged: viewMode.setMode,
                ),
              ],
            ),
          ),
        ],
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
                  Expanded(
                    child: Text(
                      'On-device only',
                      style: MqTextStyles.headline.copyWith(color: c.textPri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MqSpacing.sm),
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
                  Expanded(
                    child: Text(
                      'Masquerade',
                      style: MqTextStyles.headline.copyWith(color: c.textPri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MqSpacing.sm),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfoFuture,
                    builder:
                        (BuildContext _, AsyncSnapshot<PackageInfo> snap) =>
                            Text(
                              snap.hasData ? 'v${snap.data!.version}' : 'v…',
                              style: MqTextStyles.subhead.copyWith(
                                color: c.textTer,
                                fontFamily: MqTextStyles.monoFamily,
                                fontFamilyFallback: MqTextStyles.monoFallback,
                              ),
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
