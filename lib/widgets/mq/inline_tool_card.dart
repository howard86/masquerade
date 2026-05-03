import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import 'mq_icons.dart';

/// Collapsible card that hosts a tool body inline. Header shows the tool
/// identity and a chevron; tapping the header invokes [onToggle]. The
/// [bodyBuilder] is only invoked when [expanded] is true, so a collapsed card
/// keeps zero state — toggling off disposes the body's State (controllers,
/// timers, recorder).
class InlineToolCard extends StatelessWidget {
  const InlineToolCard({
    super.key,
    required this.descriptor,
    required this.expanded,
    required this.onToggle,
    required this.bodyBuilder,
  });

  final UtilityDescriptor descriptor;
  final bool expanded;
  final VoidCallback onToggle;
  final WidgetBuilder bodyBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;

    return Semantics(
      button: true,
      expanded: expanded,
      label: descriptor.name,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MqRadius.lg),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: c.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: descriptor.tint,
                        borderRadius: BorderRadius.circular(MqRadius.xs + 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        descriptor.icon,
                        size: 18,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(width: MqSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            descriptor.name,
                            style: MqTextStyles.subhead.copyWith(
                              color: c.textPri,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            descriptor.description,
                            style: MqTextStyles.caption1.copyWith(
                              color: c.textSec,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MqSpacing.sm),
                    Icon(
                      expanded ? MqIcons.chevD : MqIcons.chevR,
                      size: 16,
                      color: c.textTer,
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: MqMotion.normal,
                curve: MqMotion.standard,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          MqSpacing.lg,
                          0,
                          MqSpacing.lg,
                          MqSpacing.lg,
                        ),
                        child: Builder(builder: bodyBuilder),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
