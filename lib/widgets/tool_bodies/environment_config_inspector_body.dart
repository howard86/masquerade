import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/environment_config_inspector.dart';
import '../../utils/text_truncate.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class EnvironmentConfigInspectorBody extends StatefulWidget
    implements ToolBodyWidget {
  const EnvironmentConfigInspectorBody({
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
  State<EnvironmentConfigInspectorBody> createState() =>
      _EnvironmentConfigInspectorBodyState();
}

class _EnvironmentConfigInspectorBodyState
    extends State<EnvironmentConfigInspectorBody>
    with ToolBodyScaffold<EnvironmentConfigInspectorBody> {
  final TextEditingController _comparisonController = TextEditingController();
  Timer? _comparisonDebounce;
  ConfigInspection? _inspection;
  ConfigInspection? _comparisonInspection;
  ConfigConversion? _conversion;
  ConfigComparison? _comparison;
  String _normalized = '';
  String _sortedNormalized = '';
  String? _error;
  String? _comparisonError;
  ConfigFormat? _format;
  bool _sort = false;
  int _duplicateLimit = 20;

  static const int _maxRouteCharacters = 64 * 1024;

  @override
  String get utilityId => 'environment_config_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 250);

  @override
  void parse(String input) {
    try {
      final ConfigInspection inspection = EnvironmentConfigInspector.parse(
        input,
        format: _format,
      );
      setState(() {
        _inspection = inspection;
        _conversion = inspection.convert();
        _normalized = inspection.normalized();
        _sortedNormalized = inspection.normalized(sort: true);
        _error = null;
        _duplicateLimit = 20;
      });
      _parseComparison();
    } on ConfigInspectorException catch (error) {
      setState(() {
        _inspection = null;
        _conversion = null;
        _comparison = null;
        _normalized = '';
        _sortedNormalized = '';
        _error = error.message;
      });
    }
  }

  @override
  void reset() => setState(() {
    _inspection = null;
    _comparisonInspection = null;
    _conversion = null;
    _comparison = null;
    _normalized = '';
    _sortedNormalized = '';
    _error = null;
    _comparisonError = null;
    _duplicateLimit = 20;
  });

  @override
  void dispose() {
    _comparisonDebounce?.cancel();
    _comparisonController.dispose();
    super.dispose();
  }

  void _selectFormat(ConfigFormat? format) {
    setState(() => _format = format);
    reparse();
  }

  void _onComparisonChanged(String _) {
    _comparisonDebounce?.cancel();
    _comparisonDebounce = Timer(
      const Duration(milliseconds: 250),
      _parseComparison,
    );
  }

  void _parseComparison() {
    if (!mounted) return;
    final String input = _comparisonController.text;
    if (input.trim().isEmpty) {
      setState(() {
        _comparisonInspection = null;
        _comparison = null;
        _comparisonError = null;
      });
      return;
    }
    try {
      final ConfigInspection inspection = EnvironmentConfigInspector.parse(
        input,
        format: _format ?? _inspection?.format,
      );
      setState(() {
        _comparisonInspection = inspection;
        _comparison = _inspection?.compare(inspection);
        _comparisonError = null;
      });
    } on ConfigInspectorException catch (error) {
      setState(() {
        _comparisonInspection = null;
        _comparison = null;
        _comparisonError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConfigInspection? inspection = _inspection;
    final String normalized = _sort ? _sortedNormalized : _normalized;
    final ConfigConversion? conversion = _conversion;
    final ConfigComparison? comparison = _comparison;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        inspection?.hadSensitiveInput == true ||
        _comparisonInspection?.hadSensitiveInput == true ||
        route?.protectedSession == true;
    final bool mayRoute =
        !protectedLineage ||
        (route?.addNext == true && route?.protectedSession == true);
    final bool routeSizeSafe = normalized.length <= _maxRouteCharacters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Configuration A',
          placeholder: 'Paste .env, properties, headers, or key/value text…',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          semanticsLabel:
              'Configuration input. Secrets are removed from outputs.',
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label: 'Local only — history disabled and exports redacted',
          kind: MqStatusKind.info,
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            _FormatButton(
              label: 'Auto',
              selected: _format == null,
              onPressed: () => _selectFormat(null),
            ),
            for (final ConfigFormat format in ConfigFormat.values)
              _FormatButton(
                label: _formatLabel(format),
                selected: _format == format,
                onPressed: () => _selectFormat(format),
              ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (inspection != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          MqSectionHeader(label: _formatLabel(inspection.format)),
          MqStatus(
            label: '${inspection.entries.length} entries',
            kind: MqStatusKind.neutral,
          ),
          const SizedBox(height: MqSpacing.sm),
          if (inspection.hadSensitiveInput) ...<Widget>[
            const MqStatus(label: 'Secrets masked', kind: MqStatusKind.warning),
            const SizedBox(height: MqSpacing.sm),
          ],
          for (final ConfigDuplicate duplicate in inspection.duplicates.take(
            _duplicateLimit,
          )) ...<Widget>[
            MqStatus(
              label: _duplicateLabel(duplicate),
              kind: MqStatusKind.warning,
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
          if (inspection.duplicates.length > _duplicateLimit) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'Show 20 more duplicates',
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: () => setState(() => _duplicateLimit += 20),
              ),
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              MqButton(
                label: _sort ? 'Original order' : 'Sort keys',
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: () => setState(() => _sort = !_sort),
              ),
              MqButton(
                label: 'Copy redacted',
                semanticsLabel: 'Copy full redacted normalized configuration',
                icon: CupertinoIcons.doc_on_doc,
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: normalized.isEmpty
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: normalized)),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          MqMonoCell(
            label: 'Redacted normalized',
            value: truncateWithEllipsis(normalized, max: 8192),
            copyable: false,
            accent: true,
          ),
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Convert'),
          if (conversion?.warning != null) ...<Widget>[
            MqStatus(label: conversion!.warning!, kind: MqStatusKind.warning),
            const SizedBox(height: MqSpacing.sm),
          ],
          if (conversion?.available == true) ...<Widget>[
            _ConversionCard(
              label: 'JSON',
              value: conversion!.json!,
              onSwitchTool:
                  mayRoute && conversion.json!.length <= _maxRouteCharacters
                  ? widget.onSwitchTool
                  : null,
            ),
            const SizedBox(height: MqSpacing.sm),
            _ConversionCard(
              label: 'YAML',
              value: conversion.yaml!,
              onSwitchTool:
                  mayRoute && conversion.yaml!.length <= _maxRouteCharacters
                  ? widget.onSwitchTool
                  : null,
            ),
          ],
          if (!routeSizeSafe) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            const MqStatus(
              label: 'Large output remains copyable but is too large to route',
              kind: MqStatusKind.info,
            ),
          ],
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Compare'),
          MqInput(
            controller: _comparisonController,
            label: 'Configuration B',
            placeholder: 'Paste another environment…',
            multiline: true,
            minLines: 3,
            maxLines: 8,
            onChanged: _onComparisonChanged,
            semanticsLabel:
                'Comparison configuration. Secrets are removed from output.',
          ),
          if (_comparisonError != null) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqStatus(label: _comparisonError!, kind: MqStatusKind.danger),
          ],
          if (comparison != null) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            MqStatus(
              label: comparison.identical
                  ? 'No semantic differences'
                  : '${comparison.added} added · ${comparison.removed} removed · ${comparison.changed} changed',
              kind: comparison.identical
                  ? MqStatusKind.success
                  : MqStatusKind.info,
            ),
            if (comparison.tooLarge) ...<Widget>[
              const SizedBox(height: MqSpacing.sm),
              const MqStatus(
                label: 'Comparison exceeds the Diff limit',
                kind: MqStatusKind.warning,
              ),
            ] else if (comparison.unifiedDiff.isNotEmpty) ...<Widget>[
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(
                label: 'Redacted unified diff',
                value: truncateWithEllipsis(comparison.unifiedDiff, max: 8192),
                copyable: false,
              ),
              const SizedBox(height: MqSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: MqSpacing.sm,
                  runSpacing: MqSpacing.sm,
                  children: <Widget>[
                    MqButton(
                      label: 'Copy full redacted diff',
                      variant: MqButtonVariant.glass,
                      size: MqButtonSize.sm,
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: comparison.unifiedDiff),
                      ),
                    ),
                    if (mayRoute &&
                        routeSizeSafe &&
                        widget.onSwitchTool != null)
                      MqButton(
                        label: 'Open A in Diff',
                        semanticsLabel:
                            'Open redacted configuration A in Diff tool',
                        variant: MqButtonVariant.tinted,
                        size: MqButtonSize.sm,
                        onPressed: () => widget.onSwitchTool!(
                          UtilityCatalog.byId('diff'),
                          normalized,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (mayRoute && routeSizeSafe)
            OpenInFooter(
              output: normalized,
              excludeUtilityId: utilityId,
              onSwitchTool: widget.onSwitchTool,
              protectedSource: protectedLineage,
            ),
        ],
      ],
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MqButton(
    label: label,
    variant: selected ? MqButtonVariant.tinted : MqButtonVariant.glass,
    size: MqButtonSize.sm,
    onPressed: onPressed,
  );
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({
    required this.label,
    required this.value,
    required this.onSwitchTool,
  });
  final String label;
  final String value;
  final OpenInToolCallback? onSwitchTool;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      MqMonoCell(
        label: label,
        value: truncateWithEllipsis(value, max: 4096),
        copyable: false,
      ),
      const SizedBox(height: MqSpacing.sm),
      Wrap(
        spacing: MqSpacing.sm,
        runSpacing: MqSpacing.sm,
        children: <Widget>[
          MqButton(
            label: 'Copy $label',
            semanticsLabel: 'Copy full redacted $label conversion',
            variant: MqButtonVariant.glass,
            size: MqButtonSize.sm,
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
          if (onSwitchTool != null)
            MqButton(
              label: 'Open in JSON',
              semanticsLabel: 'Open redacted $label conversion in JSON tool',
              variant: MqButtonVariant.tinted,
              size: MqButtonSize.sm,
              onPressed: () =>
                  onSwitchTool!(UtilityCatalog.byId('json'), value),
            ),
        ],
      ),
    ],
  );
}

String _formatLabel(ConfigFormat format) => switch (format) {
  ConfigFormat.environment => '.env',
  ConfigFormat.properties => 'Properties',
  ConfigFormat.headers => 'Headers',
  ConfigFormat.keyValue => 'Key/value',
};

String _duplicateLabel(ConfigDuplicate duplicate) {
  final String key = truncateWithEllipsis(duplicate.key, max: 64);
  final List<int> shown = duplicate.lines.take(8).toList();
  final int remaining = duplicate.lines.length - shown.length;
  return 'Duplicate $key on lines ${shown.join(', ')}${remaining > 0 ? ' (+$remaining more)' : ''}';
}
