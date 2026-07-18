import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_metrics.dart';
import '../../state/detection_preference_controller.dart';
import '../../utility_catalog.dart';
import '../../utils/copy_util.dart';
import '../../utils/sensitive_data_policy.dart';
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
    this.protectedSource = false,
  });

  final String? output;
  final String excludeUtilityId;
  final OpenInToolCallback? onSwitchTool;
  final bool protectedSource;

  @override
  Widget build(BuildContext context) {
    final String? out = output;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool addNext = route?.addNext ?? false;
    final bool lineageProtected =
        protectedSource || (route?.protectedSession ?? false);
    final bool contentProtected =
        out != null && SensitiveDataPolicy.containsSensitiveArtifact(out);
    if (out == null ||
        out.isEmpty ||
        onSwitchTool == null ||
        contentProtected ||
        (lineageProtected && !addNext)) {
      return const SizedBox.shrink();
    }
    final DetectionPreferenceController? preferences =
        DetectionPreferenceScope.maybeOf(context);
    final List<UtilityDescriptor> targets = UtilityCatalog.compatibleNextSteps(
      excludeUtilityId,
      out,
      rank: preferences?.rank,
    ).where((UtilityDescriptor u) => u.id != excludeUtilityId).toList();
    if (targets.isEmpty) return const SizedBox.shrink();
    final String action = addNext ? 'Add next step' : 'Open in';

    return Padding(
      padding: const EdgeInsets.only(top: MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MqSectionHeader(label: action),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              for (final UtilityDescriptor u in targets)
                _OpenInChip(
                  descriptor: u,
                  output: out,
                  onSwitchTool: onSwitchTool!,
                  action: action,
                  allowCopy: !lineageProtected,
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
    required this.action,
    required this.allowCopy,
  });

  final UtilityDescriptor descriptor;
  final String output;
  final OpenInToolCallback onSwitchTool;
  final String action;
  final bool allowCopy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$action ${descriptor.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onSwitchTool(descriptor, output);
        },
        onLongPress: () {
          if (allowCopy) CopyToClipboardUtil.copyToClipboard(context, output);
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

/// Marks the current mobile session route without changing desktop callers.
class MobileSessionRouteScope extends InheritedWidget {
  const MobileSessionRouteScope({
    super.key,
    required this.addNext,
    required this.protectedSession,
    required super.child,
  });

  final bool addNext;
  final bool protectedSession;

  static MobileSessionRouteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileSessionRouteScope>();

  @override
  bool updateShouldNotify(MobileSessionRouteScope oldWidget) =>
      addNext != oldWidget.addNext ||
      protectedSession != oldWidget.protectedSession;
}
