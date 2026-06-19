import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/copy_util.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_section_header.dart';

/// Cross-tool pipe footer. Detects which catalog tools accept [output] and
/// renders an "Open in" chip row. Tap routes through [onSwitchTool]; long
/// press copies the output to the clipboard before routing.
class OpenInFooter extends StatelessWidget {
  const OpenInFooter({
    super.key,
    required this.output,
    required this.excludeUtilityId,
    this.onSwitchTool,
  });

  final String? output;
  final String excludeUtilityId;
  final OpenInToolCallback? onSwitchTool;

  @override
  Widget build(BuildContext context) {
    final String? out = output;
    if (out == null || out.isEmpty || onSwitchTool == null) {
      return const SizedBox.shrink();
    }
    final List<UtilityDescriptor> targets = UtilityCatalog.detectAll(
      out,
    ).where((UtilityDescriptor u) => u.id != excludeUtilityId).toList();
    if (targets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MqSectionHeader(label: 'Open in'),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              for (final UtilityDescriptor u in targets)
                _OpenInChip(
                  descriptor: u,
                  output: out,
                  onSwitchTool: onSwitchTool!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenInChip extends StatelessWidget {
  const _OpenInChip({
    required this.descriptor,
    required this.output,
    required this.onSwitchTool,
  });

  final UtilityDescriptor descriptor;
  final String output;
  final OpenInToolCallback onSwitchTool;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open in ${descriptor.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onSwitchTool(descriptor, output);
        },
        onLongPress: () {
          CopyToClipboardUtil.copyToClipboard(context, output);
          HapticFeedback.selectionClick();
          onSwitchTool(descriptor, output);
        },
        child: MqChip(
          label: descriptor.name,
          icon: descriptor.icon,
          accent: true,
          mono: false,
        ),
      ),
    );
  }
}
