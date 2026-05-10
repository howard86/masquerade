import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class MqWordmark extends StatelessWidget {
  const MqWordmark({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final TextStyle base = MqTextStyles.display.copyWith(
      color: color ?? c.accent,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: size != null ? 1.1 : null,
    );
    return Text('Masquerade', style: base);
  }
}
