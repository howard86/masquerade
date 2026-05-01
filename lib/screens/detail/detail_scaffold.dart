import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class MqDetailScaffold extends StatelessWidget {
  const MqDetailScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomBar,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.bg.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        middle: Text(
          title,
          style: MqTextStyles.headline.copyWith(color: c.textPri),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.lg,
                  MqSpacing.lg,
                  MqSpacing.lg,
                  MqSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      title,
                      style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
                    ),
                    const SizedBox(height: MqSpacing.xs),
                    Text(
                      subtitle,
                      style: MqTextStyles.subhead.copyWith(color: c.textSec),
                    ),
                    const SizedBox(height: MqSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.lg,
                  MqSpacing.sm,
                  MqSpacing.lg,
                  MqSpacing.md,
                ),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}
