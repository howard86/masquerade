import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';

/// Masquerade card surface. Hairline border, no shadow by default. Pass
/// `floating: true` for modal/toast surfaces that need a drop shadow.
class MqSurface extends StatelessWidget {
  const MqSurface({
    super.key,
    required this.child,
    this.padded = true,
    this.floating = false,
    this.padding,
    this.radius = MqRadius.md,
    this.background,
    this.borderColor,
  });

  final Widget child;
  final bool padded;

  /// True for floating surfaces (modals, toasts) that earn a drop shadow.
  /// Cards default to flat hairline-only.
  final bool floating;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? tokens.colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? tokens.colors.border,
          width: 0.5,
        ),
        boxShadow: floating ? tokens.colors.shadowLg : null,
      ),
      child: Padding(
        padding:
            padding ??
            (padded ? const EdgeInsets.all(MqSpacing.lg) : EdgeInsets.zero),
        child: child,
      ),
    );
  }
}
