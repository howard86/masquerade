import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../models/artifact.dart';
import '../../state/detection_preference_controller.dart';
import '../../utility_catalog.dart';
import '../../utils/copy_util.dart';
import '../../utils/sensitive_data_policy.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_surface.dart';

/// Cross-tool pipe footer. Detects which catalog tools accept [output] and
/// renders an "Open in" chip row. Tap routes through [onSwitchTool]; long
/// press copies the output to the clipboard before routing.
///
/// The sensitive-content scan and the detection sweep run once per distinct
/// [output], not per build: bodies rebuild on every keystroke, and desktop
/// windows on every drag frame, usually with the same output. Ranking by
/// detection preference and the [excludeUtilityId] filter stay per build
/// because they are cheap and change independently of the output.
class OpenInFooter extends StatefulWidget {
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
  State<OpenInFooter> createState() => _OpenInFooterState();
}

class _OpenInFooterState extends State<OpenInFooter> {
  String? _sensitiveOutput;
  bool _sensitive = false;
  String? _detectedOutput;
  List<DetectionMatch<Object?>> _matches = const <DetectionMatch<Object?>>[];

  bool _containsSensitive(String out) {
    if (!_sameOutput(out, _sensitiveOutput)) {
      _sensitive = SensitiveDataPolicy.containsSensitiveArtifact(out);
      _sensitiveOutput = out;
    }
    return _sensitive;
  }

  List<DetectionMatch<Object?>> _detect(String out) {
    if (!_sameOutput(out, _detectedOutput)) {
      _matches = UtilityCatalog.detectArtifacts(
        out,
        provenance: ArtifactProvenance.generated,
      );
      _detectedOutput = out;
    }
    return _matches;
  }

  static bool _sameOutput(String out, String? cached) =>
      cached != null && (identical(out, cached) || out == cached);

  @override
  Widget build(BuildContext context) {
    final String? out = widget.output;
    final OpenInToolCallback? onSwitchTool = widget.onSwitchTool;
    final String excludeUtilityId = widget.excludeUtilityId;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool addNext = route?.addNext ?? false;
    final bool lineageProtected =
        widget.protectedSource || (route?.protectedSession ?? false);
    final bool contentProtected = out != null && _containsSensitive(out);
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
      matches: _detect(out),
    ).where((UtilityDescriptor u) => u.id != excludeUtilityId).toList();
    final String? expectedId = route?.expectedNextToolId;
    if (expectedId != null &&
        !targets.any((UtilityDescriptor target) => target.id == expectedId)) {
      final String name =
          UtilityCatalog.byIdOrNull(expectedId)?.name ?? expectedId;
      final String error = 'Output is not compatible with $name.';
      final c = context.mq.colors;
      return Padding(
        padding: const EdgeInsets.only(top: MqSpacing.md),
        child: Semantics(
          liveRegion: true,
          label: error,
          excludeSemantics: true,
          child: MqSurface(
            background: c.warningBg,
            borderColor: c.warning,
            child: Text(
              error,
              style: MqTextStyles.subhead.copyWith(color: c.textPri),
            ),
          ),
        ),
      );
    }
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
                  onSwitchTool: onSwitchTool,
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
    this.expectedNextToolId,
    this.settings = const <String, Object?>{},
    this.onSettingsChanged,
    required super.child,
  });

  final bool addNext;
  final bool protectedSession;
  final String? expectedNextToolId;
  final Map<String, Object?> settings;
  final ValueChanged<Map<String, Object?>>? onSettingsChanged;

  static MobileSessionRouteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileSessionRouteScope>();

  @override
  bool updateShouldNotify(MobileSessionRouteScope oldWidget) =>
      addNext != oldWidget.addNext ||
      protectedSession != oldWidget.protectedSession ||
      expectedNextToolId != oldWidget.expectedNextToolId ||
      settings != oldWidget.settings ||
      onSettingsChanged != oldWidget.onSettingsChanged;
}
