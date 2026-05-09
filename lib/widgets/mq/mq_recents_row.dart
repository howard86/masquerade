import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import 'mq_chip.dart';
import 'mq_section_header.dart';

/// Editorial "Recents" row — hairline divider above + chip list.
class MqRecentsRow extends StatelessWidget {
  const MqRecentsRow({
    super.key,
    required this.recents,
    required this.expanded,
    required this.onTap,
  });

  final List<UtilityDescriptor> recents;
  final UtilityDescriptor? expanded;
  final void Function(UtilityDescriptor) onTap;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) return const SizedBox.shrink();
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border, width: 0.5)),
          ),
          child: const Padding(
            padding: EdgeInsets.only(top: MqSpacing.sm),
            child: MqSectionHeader(label: 'Recents'),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < recents.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: MqSpacing.sm),
                MqChip(
                  label: recents[i].name,
                  icon: recents[i].icon,
                  accent: recents[i] == expanded,
                  mono: false,
                  onTap: () => onTap(recents[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
