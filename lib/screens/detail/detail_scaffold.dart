import 'package:flutter/cupertino.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';

class MBDetailScaffold extends StatelessWidget {
  const MBDetailScaffold({
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
    final c = context.mb.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.bg.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        middle: Text(
          title,
          style: MBTextStyles.headline.copyWith(color: c.textPri),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MBSpacing.lg,
                  MBSpacing.lg,
                  MBSpacing.lg,
                  MBSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      title,
                      style: MBTextStyles.largeTitle.copyWith(color: c.textPri),
                    ),
                    const SizedBox(height: MBSpacing.xs),
                    Text(
                      subtitle,
                      style: MBTextStyles.subhead.copyWith(color: c.textSec),
                    ),
                    const SizedBox(height: MBSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MBSpacing.lg,
                  MBSpacing.sm,
                  MBSpacing.lg,
                  MBSpacing.md,
                ),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}
