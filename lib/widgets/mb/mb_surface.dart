import 'package:flutter/widgets.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';

/// Magic Box card surface. Radius 18, 0.5px border, optional elevated shadow.
class MBSurface extends StatelessWidget {
  const MBSurface({
    super.key,
    required this.child,
    this.padded = true,
    this.elevated = false,
    this.padding,
    this.radius = MBRadius.lg,
    this.background,
    this.borderColor,
  });

  final Widget child;
  final bool padded;
  final bool elevated;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? tokens.colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? tokens.colors.border,
          width: 0.5,
        ),
        boxShadow: elevated ? tokens.colors.shadowLg : tokens.colors.shadow,
      ),
      child: Padding(
        padding:
            padding ??
            (padded ? const EdgeInsets.all(MBSpacing.lg) : EdgeInsets.zero),
        child: child,
      ),
    );
  }
}
