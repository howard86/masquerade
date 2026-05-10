import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';

/// Vertical-rhythm container for body content. Inserts 24px between paragraph
/// children and 40px between paragraph and heading children. Children are
/// classified by [ReadingHeading] vs anything else.
class ReadingBlock extends StatelessWidget {
  const ReadingBlock({
    super.key,
    required this.children,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final List<Widget> spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        final bool nextIsHeading = children[i] is ReadingHeading;
        spaced.add(SizedBox(height: nextIsHeading ? 40 : MqSpacing.xl));
      }
      spaced.add(children[i]);
    }
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: spaced,
      ),
    );
  }
}

/// Marker wrapper for headings inside a [ReadingBlock] — earns 40px space
/// above instead of the default 24px paragraph rhythm.
class ReadingHeading extends StatelessWidget {
  const ReadingHeading({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
