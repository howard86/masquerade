import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/csv_parser.dart';
import '../../utils/copy_util.dart';
import '../../utils/sensitive_data_policy.dart';
import '../../utils/utf8_length.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

enum CsvMode { csvToJson, jsonToCsv, inspect }

class CsvBody extends StatefulWidget implements ToolBodyWidget {
  const CsvBody({
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
  State<CsvBody> createState() => _CsvBodyState();
}

class _CsvBodyState extends State<CsvBody> with ToolBodyScaffold<CsvBody> {
  final ScrollController _tableScroll = ScrollController();
  CsvMode _mode = CsvMode.csvToJson;
  CsvOk? _parsed;
  String? _output;
  String? _error;
  bool _scalarTypesLost = false;
  bool _formulaLike = false;
  // Derived from [_output] once per parse rather than on every build.
  String? _outputPreview;
  bool? _outputSensitive;

  @override
  String get utilityId => 'csv';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void dispose() {
    _tableScroll.dispose();
    super.dispose();
  }

  @override
  void parse(String input) {
    CsvOk? parsed;
    String? output;
    String? error;
    bool scalarTypesLost = false;
    bool formulaLike = false;
    try {
      if (_mode == CsvMode.jsonToCsv) {
        final ({String csv, List<List<String>> records, bool typedScalars})
        converted = CsvParser.fromJsonRecords(input);
        output = converted.csv;
        scalarTypesLost = converted.typedScalars;
        // The warning used to scan a re-parse of [output], which rejects
        // output over the parser's input cap; keep that bound.
        formulaLike =
            !utf8LengthExceeds(output, CsvParser.maxInputChars) &&
            converted.records.any(
              (List<String> row) => row.any(_formulaLikeValue),
            );
      } else {
        final CsvParseResult result = CsvParser.parse(input);
        if (result is CsvErr) {
          error = result.message;
        } else {
          parsed = result as CsvOk;
          output = CsvParser.toJson(parsed);
        }
      }
    } on FormatException catch (exception) {
      error = exception.message;
    }
    setState(() {
      _parsed = parsed;
      _output = output;
      _outputPreview = output == null ? null : _preview(output);
      _outputSensitive = null;
      _error = error;
      _scalarTypesLost = scalarTypesLost;
      _formulaLike = formulaLike;
    });
    if (error == null &&
        output != null &&
        widget.initialArtifact?.isSensitive != true) {
      recordOutput(input, output);
    }
  }

  @override
  void reset() => setState(() {
    _parsed = null;
    _output = null;
    _outputPreview = null;
    _outputSensitive = null;
    _error = null;
    _scalarTypesLost = false;
    _formulaLike = false;
  });

  void _setMode(CsvMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    reparse();
  }

  bool _mayRouteJson(BuildContext context, String output) {
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        route?.protectedSession == true;
    final bool sensitive = _outputSensitive ??=
        SensitiveDataPolicy.containsSensitiveArtifact(output);
    return !sensitive &&
        (!protectedLineage ||
            (route?.addNext == true && route?.protectedSession == true));
  }

  @override
  Widget build(BuildContext context) {
    final CsvOk? parsed = _parsed;
    final String? output = _output;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: _mode == CsvMode.jsonToCsv ? 'JSON' : 'CSV / TSV',
          placeholder: _mode == CsvMode.jsonToCsv
              ? '[{"name":"Ada"}]'
              : 'name,language\nAda,Dart',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
        ),
        const SizedBox(height: MqSpacing.md),
        MqSegmented<CsvMode>(
          options: const <CsvMode, String>{
            CsvMode.csvToJson: 'CSV → JSON',
            CsvMode.jsonToCsv: 'JSON → CSV',
            CsvMode.inspect: 'Inspect',
          },
          selected: _mode,
          onChanged: _setMode,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (_mode == CsvMode.inspect && parsed != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          _Metadata(parsed: parsed),
          const SizedBox(height: MqSpacing.lg),
          _CsvTable(parsed: parsed, controller: _tableScroll),
        ] else if (output != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: _mode == CsvMode.jsonToCsv ? 'CSV' : 'JSON',
            value: _outputPreview ?? _preview(output),
            copyValue: output,
          ),
          if (_mode == CsvMode.jsonToCsv && _formulaLike)
            const Padding(
              padding: EdgeInsets.only(top: MqSpacing.sm),
              child: MqStatus(
                label:
                    'Values are preserved exactly. Spreadsheet apps may execute cells beginning with =, +, -, or @.',
                kind: MqStatusKind.warning,
              ),
            ),
          if (_mode == CsvMode.jsonToCsv && _scalarTypesLost)
            const Padding(
              padding: EdgeInsets.only(top: MqSpacing.sm),
              child: MqStatus(
                label:
                    'CSV has no value types. Numbers and booleans become text when re-imported.',
                kind: MqStatusKind.warning,
              ),
            ),
          if (_mode == CsvMode.csvToJson &&
              widget.onSwitchTool != null &&
              _mayRouteJson(context, output)) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            MqButton(
              label: 'Open JSON output in JSON tool',
              variant: MqButtonVariant.tinted,
              full: true,
              onPressed: () =>
                  widget.onSwitchTool!(UtilityCatalog.byId('json'), output),
            ),
          ],
        ] else if (_error == null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          const MqEmptyHint(label: 'Paste tabular data to convert or inspect.'),
        ],
      ],
    );
  }

  static String _preview(String output) => _safePreview(output, 20000);

  static bool _formulaLikeValue(String value) {
    final String trimmed = value.trimLeft();
    return trimmed.isNotEmpty &&
        const <String>{'=', '+', '-', '@'}.contains(trimmed[0]);
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.parsed});

  final CsvOk parsed;

  @override
  Widget build(BuildContext context) {
    final int columns =
        parsed.header?.length ??
        (parsed.rows.isEmpty ? 0 : parsed.rows.first.length);
    final String delimiter = switch (parsed.delimiter) {
      '\t' => 'Tab',
      ';' => 'Semicolon',
      _ => 'Comma',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MqSectionHeader(label: 'Detected'),
        MqStatus(
          label:
              '$delimiter · ${parsed.rows.length} rows · $columns columns · ${parsed.hasHeader ? 'header' : 'no header'}',
          kind: MqStatusKind.info,
        ),
        if (parsed.header != null) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Header',
            value: _safePreview(parsed.header!.join(' · '), 256),
            copyValue: parsed.header!.join(' · '),
          ),
        ],
      ],
    );
  }
}

class _CsvTable extends StatelessWidget {
  const _CsvTable({required this.parsed, required this.controller});

  final CsvOk parsed;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final List<List<String>> rows = <List<String>>[
      if (parsed.header != null) parsed.header!,
      ...parsed.rows.take(200),
    ];
    final int columns = rows.isEmpty ? 0 : rows.first.length;
    if (columns == 0) return const SizedBox.shrink();
    final colors = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MqSectionHeader(label: 'Table preview'),
        MqStatus(
          label:
              'Showing ${parsed.rows.length > 200 ? 200 : parsed.rows.length} of ${parsed.rows.length} rows',
          kind: MqStatusKind.info,
        ),
        const SizedBox(height: MqSpacing.sm),
        MqSurface(
          padded: false,
          child: CupertinoScrollbar(
            controller: controller,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: columns * 160,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(160),
                  border: TableBorder.all(color: colors.border, width: 0.5),
                  children: <TableRow>[
                    for (int row = 0; row < rows.length; row++)
                      TableRow(
                        decoration: row == 0 && parsed.header != null
                            ? BoxDecoration(color: colors.surface2)
                            : null,
                        children: <Widget>[
                          for (final (int column, String cell)
                              in rows[row].indexed)
                            Padding(
                              padding: const EdgeInsets.all(MqSpacing.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _safePreview(cell, 256),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: MqTextStyles.monoSm.copyWith(
                                        color: colors.monoText,
                                      ),
                                    ),
                                  ),
                                  if (cell.length > 256)
                                    AnimatedCopyIcon(
                                      key: ValueKey<String>(
                                        'csv-cell-$row-$column',
                                      ),
                                      semanticsLabel: 'Copy full cell',
                                      onCopy: () => Clipboard.setData(
                                        ClipboardData(text: cell),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _safePreview(String value, int maxCodePoints) {
  // Code points never outnumber code units.
  if (value.length <= maxCodePoints) return value;
  final List<int> points = value.runes
      .take(maxCodePoints + 1)
      .toList(growable: false);
  if (points.length <= maxCodePoints) return value;
  return '${String.fromCharCodes(points.take(maxCodePoints))}… [preview truncated]';
}
