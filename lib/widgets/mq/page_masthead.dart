import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Editorial masthead — display-tier title in Plex Serif, optional Plex Sans
/// tagline, optional hairline rule beneath. Used by Home + tool-hero screens.
class PageMasthead extends StatelessWidget {
  const PageMasthead({
    super.key,
    required this.title,
    this.tagline,
    this.rule = true,
    this.padding,
  });

  final String title;
  final String? tagline;

  /// Draws a full-width hairline beneath the tagline. True by default.
  final bool rule;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(0, MqSpacing.lg, 0, MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: MqTextStyles.display.copyWith(color: c.textPri)),
          if (tagline != null) ...<Widget>[
            const SizedBox(height: MqSpacing.xs),
            Text(
              tagline!,
              style: MqTextStyles.subhead.copyWith(color: c.textSec),
            ),
          ],
          if (rule) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            Container(height: 0.5, color: c.border),
          ],
        ],
      ),
    );
  }
}
