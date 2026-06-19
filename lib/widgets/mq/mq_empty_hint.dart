import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Editorial empty state — Plex Serif italic line, no illustration.
class MqEmptyHint extends StatelessWidget {
  const MqEmptyHint({super.key, required this.label, this.detail});

  final String label;

  /// Optional second-line detail rendered in Plex Sans footnote.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String? d = detail;
    // Expose the hint as a single semantic label so a screen reader reads the
    // empty state as one line rather than two unrelated text nodes.
    return Semantics(
      label: d != null ? '$label. $d' : label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: MqTextStyles.body.copyWith(
                fontFamily: MqTextStyles.serifFamily,
                fontFamilyFallback: MqTextStyles.serifFallback,
                fontStyle: FontStyle.italic,
                color: c.textSec,
              ),
            ),
            if (d != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(d, style: MqTextStyles.footnote.copyWith(color: c.textTer)),
            ],
          ],
        ),
      ),
    );
  }
}
