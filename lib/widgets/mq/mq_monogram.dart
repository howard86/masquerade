import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// "M." italic Plex Serif on a cream-square plate with a hairline border.
/// Source for AppIcon + favicon regen — render into PNG offline.
class MqMonogram extends StatelessWidget {
  const MqMonogram({
    super.key,
    this.size = 96,
    this.background,
    this.foreground,
  });

  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color bg = background ?? c.surface;
    final Color fg = foreground ?? c.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: c.borderStrong, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(top: size * 0.04),
        child: Text(
          'M.',
          style: MqTextStyles.display.copyWith(
            color: fg,
            fontStyle: FontStyle.italic,
            fontSize: size * 0.62,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
