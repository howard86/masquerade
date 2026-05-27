import 'dart:ui';
import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../mq/mq_icons.dart';

/// Shows the keyboard shortcuts HUD cheatsheet modal.
Future<void> showShortcutsHUD(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Keyboard shortcuts',
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder:
        (BuildContext ctx, Animation<double> anim, Animation<double> sec) {
          return const Align(
            alignment: Alignment.center,
            child: _ShortcutsHUD(),
          );
        },
    transitionBuilder:
        (
          BuildContext ctx,
          Animation<double> anim,
          Animation<double> sec,
          Widget child,
        ) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
  );
}

class _ShortcutsHUD extends StatelessWidget {
  const _ShortcutsHUD();

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      width: 460,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(MqRadius.md),
        border: Border.all(color: c.borderStrong, width: 0.5),
        boxShadow: c.shadowLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MqRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(MqSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(MqIcons.keyboard, size: 20, color: c.accent),
                    const SizedBox(width: MqSpacing.sm),
                    Text(
                      'Desktop Shortcuts',
                      style: MqTextStyles.title3.copyWith(color: c.textPri),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(MqIcons.clear, size: 18, color: c.textTer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MqSpacing.md),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: MqSpacing.xs),
                  child: SizedBox(
                    height: 0.5,
                    child: ColoredBox(color: Color(0x22FFFFFF)),
                  ),
                ),
                const SizedBox(height: MqSpacing.sm),
                const _ShortcutRow(
                  keys: <String>['⌘', 'K'],
                  label: 'Open Spotlight Search',
                ),
                const _ShortcutRow(
                  keys: <String>['⌥', '1..9'],
                  label: 'Focus Window Slot 1-9',
                ),
                const _ShortcutRow(
                  keys: <String>['⌥', 'D'],
                  label: 'Duplicate Window',
                ),
                const _ShortcutRow(
                  keys: <String>['Esc'],
                  label: 'Close Active Window',
                ),
                const _ShortcutRow(
                  keys: <String>['⌥', '/'],
                  label: 'Toggle Shortcuts HUD',
                ),
                const SizedBox(height: MqSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.label});

  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: MqTextStyles.body.copyWith(color: c.textPri),
            ),
          ),
          Wrap(
            spacing: MqSpacing.xs,
            children: <Widget>[
              for (final String key in keys) _Keycap(text: key),
            ],
          ),
        ],
      ),
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final bool isDark = context.mq.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(MqRadius.xs),
        border: Border.all(
          color: isDark ? const Color(0xFF3C3C40) : const Color(0xFFD1D1D6),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark ? const Color(0xFF18181A) : const Color(0xFFC0C0C6),
            offset: const Offset(0, 1.5),
            blurRadius: 0.5,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      child: Text(
        text,
        style: MqTextStyles.monoSm.copyWith(
          color: c.textPri,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).minWidth;
  }
}

extension on Widget {
  /// Simple helper to align keycap widths.
  Widget get minWidth =>
      Container(constraints: const BoxConstraints(minWidth: 26), child: this);
}
