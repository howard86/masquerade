import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/artifact_inspector.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class ArtifactInspectorBody extends StatefulWidget implements ToolBodyWidget {
  const ArtifactInspectorBody({
    super.key,
    this.initialInput,
    this.initialArtifact,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  @override
  final String? initialInput;
  final Artifact<Object?>? initialArtifact;
  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;
  final LinkChannel? link;

  @override
  State<ArtifactInspectorBody> createState() => _ArtifactInspectorBodyState();
}

class _ArtifactInspectorBodyState extends State<ArtifactInspectorBody>
    with ToolBodyScaffold<ArtifactInspectorBody> {
  ArtifactInspection? _inspection;

  @override
  String get utilityId => 'artifact_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void parse(String input) {
    final ArtifactInspection inspection = ArtifactInspector.inspect(
      input,
      provenance:
          widget.initialArtifact?.provenance ?? ArtifactProvenance.typed,
      inheritedSensitive:
          widget.initialArtifact?.isSensitive == true ||
          MobileSessionRouteScope.maybeOf(context)?.protectedSession == true,
    );
    setState(() => _inspection = inspection);
  }

  @override
  void reset() => setState(() => _inspection = null);

  @override
  Widget build(BuildContext context) {
    final ArtifactInspection? inspection = _inspection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'ARTIFACT',
          placeholder: 'Paste encoded or structured data…',
          multiline: true,
          minLines: 4,
          maxLines: 10,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          semanticsLabel: 'Artifact to inspect',
        ),
        const SizedBox(height: MqSpacing.lg),
        if (inspection?.error != null)
          MqStatus(label: inspection!.error!, kind: MqStatusKind.danger)
        else if (inspection?.root != null) ...<Widget>[
          MqSectionHeader(
            label: '${inspection!.nodeCount} layers',
            trailing: inspection.truncated
                ? const MqStatus(
                    label: 'Bounds reached',
                    kind: MqStatusKind.warning,
                  )
                : null,
          ),
          _LayerView(
            layer: inspection.root!,
            onSwitchTool: widget.onSwitchTool,
          ),
        ],
      ],
    );
  }
}

class _LayerView extends StatelessWidget {
  const _LayerView({
    required this.layer,
    required this.onSwitchTool,
    this.depth = 0,
  });

  final InspectorLayer layer;
  final OpenInToolCallback? onSwitchTool;
  final int depth;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: EdgeInsets.only(
          left: MqSpacing.sm * depth.clamp(0, 3),
          bottom: MqSpacing.sm,
        ),
        child: _LayerCard(layer: layer, onSwitchTool: onSwitchTool),
      ),
      for (final InspectorLayer child in layer.children)
        _LayerView(layer: child, onSwitchTool: onSwitchTool, depth: depth + 1),
    ],
  );
}

class _LayerCard extends StatelessWidget {
  const _LayerCard({required this.layer, required this.onSwitchTool});

  final InspectorLayer layer;
  final OpenInToolCallback? onSwitchTool;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final String? toolId = layer.primaryToolId;
    final UtilityDescriptor? target = toolId == null
        ? null
        : UtilityCatalog.byIdOrNull(toolId);
    final bool protectedSession =
        route?.addNext == true && route?.protectedSession == true;
    final bool canRoute =
        target != null &&
        onSwitchTool != null &&
        (!layer.isSensitive || protectedSession);
    final String action = route?.addNext == true ? 'Add next step' : 'Open in';

    return MqSurface(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            layer.label,
            style: MqTextStyles.headline.copyWith(color: c.textPri),
          ),
          if (layer.confidence case final double confidence) ...<Widget>[
            const SizedBox(height: MqSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: MqStatus(
                label: '${(confidence * 100).round()}% confidence',
                kind: MqStatusKind.info,
              ),
            ),
          ],
          const SizedBox(height: MqSpacing.xs),
          Text(
            layer.safePreview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: MqTextStyles.monoSm.copyWith(color: c.textPri),
          ),
          if (layer.evidence case final String evidence) ...<Widget>[
            const SizedBox(height: MqSpacing.xs),
            Text(
              evidence,
              style: MqTextStyles.caption1.copyWith(color: c.textSec),
            ),
          ],
          if (layer.warning case final String warning) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqStatus(label: warning, kind: MqStatusKind.warning),
          ],
          if (!layer.isSensitive || canRoute) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              children: <Widget>[
                if (!layer.isSensitive)
                  MqButton(
                    label: 'Extract layer',
                    semanticsLabel: 'Extract ${layer.label}',
                    variant: MqButtonVariant.glass,
                    size: MqButtonSize.sm,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: layer.artifact.rawValue),
                    ),
                  ),
                if (canRoute)
                  MqButton(
                    label: '$action ${target.name}',
                    semanticsLabel: '$action ${target.name}',
                    variant: MqButtonVariant.tinted,
                    size: MqButtonSize.sm,
                    onPressed: () =>
                        onSwitchTool!(target, layer.artifact.rawValue),
                  ),
              ],
            ),
          ] else if (target != null) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            const MqStatus(
              label: 'Protected layer — add from a protected session',
              kind: MqStatusKind.warning,
            ),
          ],
        ],
      ),
    );
  }
}
