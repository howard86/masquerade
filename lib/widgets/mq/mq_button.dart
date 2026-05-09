import 'package:flutter/cupertino.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Editorial button variants:
/// - [filled]: solid accent fill + onTint label (primary action).
/// - [tinted]: soft accent-tinted pill + accent ink (secondary action with emphasis).
/// - [glass]: hairline outline + ink-pri label (editorial secondary, restrained).
/// - [plain]: text-only accent label (tertiary/inline).
enum MqButtonVariant { filled, tinted, plain, glass }

enum MqButtonSize { sm, md, lg }

class MqButton extends StatelessWidget {
  const MqButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = MqButtonVariant.filled,
    this.size = MqButtonSize.md,
    this.full = false,
    this.destructive = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MqButtonVariant variant;
  final MqButtonSize size;
  final bool full;
  final bool destructive;
  final String? semanticsLabel;

  double get _height => switch (size) {
    MqButtonSize.sm => 32,
    MqButtonSize.md => 44,
    MqButtonSize.lg => 50,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;
    final Color tint = destructive ? c.danger : c.accent;
    final Color tintBg = destructive ? c.dangerBg : c.accentBg;
    final Color tintInk = destructive ? c.danger : c.accentInk;

    final ({Color bg, Color fg, Color? border}) style = switch (variant) {
      MqButtonVariant.filled => (bg: tint, fg: c.onTint, border: null),
      MqButtonVariant.tinted => (bg: tintBg, fg: tintInk, border: null),
      MqButtonVariant.plain => (
        bg: const Color(0x00000000),
        fg: tint,
        border: null,
      ),
      MqButtonVariant.glass => (
        bg: const Color(0x00000000),
        fg: c.textPri,
        border: c.borderStrong,
      ),
    };

    final TextStyle textStyle = MqTextStyles.headline.copyWith(color: style.fg);

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 16, color: style.fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );

    final Widget button = CupertinoButton(
      padding: EdgeInsets.symmetric(
        horizontal: size == MqButtonSize.sm ? 14 : 18,
      ),
      borderRadius: BorderRadius.circular(_height / 2),
      color: variant == MqButtonVariant.filled ? style.bg : null,
      pressedOpacity: 0.85,
      onPressed: onPressed,
      minimumSize: Size(0, _height),
      child: child,
    );

    final Widget skinned = variant == MqButtonVariant.filled
        ? button
        : Container(
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(_height / 2),
              border: style.border != null
                  ? Border.all(color: style.border!, width: 0.5)
                  : null,
            ),
            child: button,
          );

    final Widget sized = full
        ? SizedBox(width: double.infinity, child: skinned)
        : skinned;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel ?? label,
      child: sized,
    );
  }
}
