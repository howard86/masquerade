import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import 'mq_chip.dart';
import 'section_rule.dart';

/// Editorial "Recents" row — section rule + chip list.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionRule(label: 'Recents'),
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
