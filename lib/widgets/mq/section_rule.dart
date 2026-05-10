import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Full-width hairline divider with an optional centered uppercase label
/// floating across the rule. The label sits in `surface`-colored padding
/// so the rule appears to break around it.
class SectionRule extends StatelessWidget {
  const SectionRule({super.key, this.label, this.padding});

  /// Optional centered label (uppercase sectionLabel style).
  final String? label;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Widget rule = Container(height: 0.5, color: c.border);
    final String? l = label;
    final Widget body = l == null
        ? rule
        : Stack(
            alignment: Alignment.center,
            children: <Widget>[
              rule,
              Container(
                color: c.bg,
                padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
                child: Text(
                  l.toUpperCase(),
                  style: MqTextStyles.sectionLabel.copyWith(color: c.textSec),
                ),
              ),
            ],
          );
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: MqSpacing.md),
      child: body,
    );
  }
}
