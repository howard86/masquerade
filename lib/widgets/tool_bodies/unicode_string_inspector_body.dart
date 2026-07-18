import 'package:flutter/cupertino.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/unicode_string_inspector.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class UnicodeStringInspectorBody extends StatefulWidget
    implements ToolBodyWidget {
  const UnicodeStringInspectorBody({
    super.key,
    this.initialInput,
    this.initialArtifact,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  @override
  final String? initialInput;
  final Artifact<Object?>? initialArtifact;
  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;

  @override
  State<UnicodeStringInspectorBody> createState() =>
      _UnicodeStringInspectorBodyState();
}

class _UnicodeStringInspectorBodyState extends State<UnicodeStringInspectorBody>
    with ToolBodyScaffold<UnicodeStringInspectorBody> {
  UnicodeInspection? _inspection;
  String? _error;
  int _visibleLimit = 50;

  @override
  String get utilityId => 'unicode_string_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 250);

  @override
  bool isBlank(String input) => input.isEmpty;

  @override
  void parse(String input) {
    try {
      setState(() {
        _inspection = UnicodeStringInspector.parse(input);
        _error = null;
        _visibleLimit = 50;
      });
    } on UnicodeInspectorException catch (error) {
      setState(() {
        _inspection = null;
        _error = error.message;
      });
    }
  }

  @override
  void reset() => setState(() {
    _inspection = null;
    _error = null;
    _visibleLimit = 50;
  });

  void _apply(UnicodeNormalization form) {
    final UnicodeInspection? inspection = _inspection;
    if (inspection == null || !inspection.changes(form)) return;
    setInput(inspection.normalizedAs(form));
  }

  void _route(String toolId, String input) {
    widget.onSwitchTool?.call(UtilityCatalog.byId(toolId), input);
  }

  @override
  Widget build(BuildContext context) {
    final UnicodeInspection? inspection = _inspection;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        route?.protectedSession == true;
    final bool mayRoute =
        !protectedLineage ||
        (route?.addNext == true && route?.protectedSession == true);
    final List<UnicodeGrapheme> visible =
        inspection?.graphemes.take(_visibleLimit).toList(growable: false) ??
        const <UnicodeGrapheme>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Text',
          placeholder: 'Paste text with hard-to-see differences…',
          multiline: true,
          minLines: 4,
          maxLines: 10,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          semanticsLabel:
              'Unicode text input. Normalization changes only after an Apply button is pressed.',
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label:
              'Local inspection only — normalization never applies automatically',
          kind: MqStatusKind.info,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (inspection != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Summary'),
          MqMonoCell(
            label: 'Counts',
            value:
                '${inspection.graphemeCount} graphemes · ${inspection.codePointCount} code points · ${inspection.utf8ByteCount} UTF-8 bytes',
            copyable: false,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Line endings',
            value: inspection.lineEndings.label,
            copyable: false,
          ),
          if (inspection.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            for (final String warning in inspection.warnings) ...<Widget>[
              MqStatus(label: warning, kind: MqStatusKind.warning),
              const SizedBox(height: MqSpacing.sm),
            ],
          ],
          const SizedBox(height: MqSpacing.sm),
          const MqStatus(
            label:
                'Confusable warning is a conservative Latin/Greek/Cyrillic mixed-script heuristic, not full Unicode spoof analysis',
            kind: MqStatusKind.neutral,
          ),
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Normalize'),
          for (final UnicodeNormalization form
              in UnicodeNormalization.values) ...<Widget>[
            _NormalizationCard(
              form: form,
              value: inspection.normalizedAs(form),
              changed: inspection.changes(form),
              mayRoute:
                  mayRoute &&
                  UnicodeStringInspector.canRouteText(
                    inspection.normalizedAs(form),
                  ),
              onApply: () => _apply(form),
              onDiff: () => _route('diff', inspection.normalizedAs(form)),
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
          if (mayRoute && widget.onSwitchTool != null) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqButton(
              label: 'UTF-8 → Bytes',
              semanticsLabel: 'Open UTF-8 bytes in Bytes tool',
              variant: MqButtonVariant.tinted,
              onPressed: inspection.canRouteBytes
                  ? () => _route('bytes', inspection.bytesInput)
                  : null,
            ),
            if (!inspection.canRouteBytes)
              const Padding(
                padding: EdgeInsets.only(top: MqSpacing.sm),
                child: MqStatus(
                  label: 'Bytes routing is limited to 64 KiB',
                  kind: MqStatusKind.info,
                ),
              ),
          ],
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Clusters'),
          MqStatus(
            label:
                'Showing ${visible.length} of ${inspection.graphemeCount} grapheme clusters',
            kind: MqStatusKind.info,
          ),
          const SizedBox(height: MqSpacing.sm),
          if (inspection.truncated)
            const Padding(
              padding: EdgeInsets.only(bottom: MqSpacing.sm),
              child: MqStatus(
                label:
                    'Detailed inspection is bounded to the first 1,000 graphemes',
                kind: MqStatusKind.info,
              ),
            ),
          for (final (int index, UnicodeGrapheme grapheme)
              in visible.indexed) ...<Widget>[
            _GraphemeCard(index: index, grapheme: grapheme),
            const SizedBox(height: MqSpacing.sm),
          ],
          if (visible.length < inspection.graphemes.length)
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'Show 50 more',
                semanticsLabel: 'Show 50 more grapheme clusters',
                variant: MqButtonVariant.glass,
                onPressed: () => setState(() => _visibleLimit += 50),
              ),
            ),
        ],
      ],
    );
  }
}

class _NormalizationCard extends StatelessWidget {
  const _NormalizationCard({
    required this.form,
    required this.value,
    required this.changed,
    required this.mayRoute,
    required this.onApply,
    required this.onDiff,
  });

  final UnicodeNormalization form;
  final String value;
  final bool changed;
  final bool mayRoute;
  final VoidCallback onApply;
  final VoidCallback onDiff;

  @override
  Widget build(BuildContext context) => MqSurface(
    padding: const EdgeInsets.all(MqSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSectionHeader(label: form.label),
        MqStatus(
          label: changed ? 'Changes text' : 'Unchanged',
          kind: changed ? MqStatusKind.warning : MqStatusKind.success,
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Preview',
          value: UnicodeStringInspector.visiblePreview(value),
          copyable: false,
          sensitive: true,
        ),
        if (changed || mayRoute) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              if (changed)
                MqButton(
                  label: 'Apply ${form.label}',
                  semanticsLabel: 'Replace input with ${form.label} text',
                  variant: MqButtonVariant.tinted,
                  size: MqButtonSize.sm,
                  onPressed: onApply,
                ),
              if (mayRoute)
                MqButton(
                  label: '${form.label} → Diff',
                  semanticsLabel: 'Open ${form.label} text in Diff tool',
                  variant: MqButtonVariant.glass,
                  size: MqButtonSize.sm,
                  onPressed: onDiff,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _GraphemeCard extends StatelessWidget {
  const _GraphemeCard({required this.index, required this.grapheme});

  final int index;
  final UnicodeGrapheme grapheme;

  @override
  Widget build(BuildContext context) => MqSurface(
    padding: const EdgeInsets.all(MqSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSectionHeader(label: 'Grapheme ${index + 1}'),
        MqMonoCell(
          label: 'Cluster size',
          value:
              '${grapheme.codePointCount} code points · ${grapheme.utf8ByteCount} bytes',
          copyable: false,
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Visible form',
          value: grapheme.display,
          copyable: false,
          sensitive: true,
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Code points',
          value: grapheme.codePointLabel,
          copyable: false,
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'UTF-8 bytes',
          value: grapheme.byteLabel,
          copyable: false,
        ),
        if (grapheme.markers.isNotEmpty) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqStatus(
            label: grapheme.markers.join(', '),
            kind: MqStatusKind.warning,
          ),
        ],
        if (grapheme.detailsTruncated) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          const MqStatus(
            label: 'Per-grapheme details are bounded',
            kind: MqStatusKind.info,
          ),
        ],
      ],
    ),
  );
}
