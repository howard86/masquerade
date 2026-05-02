import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/timestamp_parser.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_empty_hint.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_status.dart';
import '../../widgets/mq/mq_surface.dart';
import 'detail_scaffold.dart';

class TimestampScreen extends StatefulWidget {
  const TimestampScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  State<TimestampScreen> createState() => _TimestampScreenState();
}

class _TimestampScreenState extends State<TimestampScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  DateTime? _parsed;
  TimestampFormat _format = TimestampFormat.unknown;
  String? _error;
  bool _ambiguous = false;
  bool _naive = false;
  String? _lastHistoryInput;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parse();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _parse);
  }

  void _parse() {
    final String input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _parsed = null;
        _error = null;
        _ambiguous = false;
        _naive = false;
      });
      return;
    }
    final TimestampParseResult result = TimestampParser.parseAnyFormat(input);
    setState(() {
      _parsed = result.timestamp;
      _format = result.format;
      _ambiguous = result.isAmbiguous;
      _naive = result.isNaive;
      _error = result.isSuccess
          ? null
          : 'Invalid input format. Supported formats:\n'
                '• Unix timestamp (seconds, ms, µs, or ns)\n'
                '• ISO 8601 date format\n'
                '• Keywords: now, today, yesterday, tomorrow,\n'
                '  or this/last/next + second/minute/hour/day/week/month/year';
    });
    if (result.isSuccess && input != _lastHistoryInput) {
      _lastHistoryInput = input;
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'timestamp',
          input: input,
          output: result.timestamp!.toIso8601String(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void _applyKeyword(String keyword) {
    _debounce?.cancel();
    _controller.text = keyword;
    _parse();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _parse();
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _parsed = null;
      _error = null;
      _ambiguous = false;
      _naive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MqDetailScaffold(
      title: 'Timestamp',
      subtitle:
          'Auto-detect ms vs s. Local TZ first; UTC + ISO + relative below.',
      bottomBar: Row(
        children: <Widget>[
          Expanded(
            child: MqButton(
              label: 'Paste',
              icon: MqIcons.paste,
              variant: MqButtonVariant.glass,
              onPressed: _paste,
              full: true,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: MqButton(
              label: 'Clear',
              icon: MqIcons.clear,
              variant: MqButtonVariant.glass,
              onPressed: _clear,
              full: true,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MqInput(
            controller: _controller,
            label: 'Input',
            placeholder:
                'Enter timestamp (Unix s/ms/µs/ns, ISO 8601, or keyword)',
            onChanged: _onChanged,
            multiline: true,
            minLines: 1,
            maxLines: 3,
            trailing: _KeywordPickerButton(onPick: _applyKeyword),
          ),
          const SizedBox(height: MqSpacing.lg),
          if (_error != null)
            MqMonoCell(
              label: 'Error',
              value: _error!,
              copyable: false,
              accent: false,
            )
          else if (_parsed != null) ...<Widget>[
            const MqSectionHeader(label: 'Output'),
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.xs,
              children: <Widget>[
                MqStatus(label: _formatLabel(_format), kind: MqStatusKind.info),
                if (_ambiguous)
                  const MqStatus(
                    label: 'Ambiguous',
                    kind: MqStatusKind.warning,
                  ),
                if (_naive)
                  const MqStatus(
                    label: 'Local TZ assumed',
                    kind: MqStatusKind.warning,
                  ),
              ],
            ),
            const SizedBox(height: MqSpacing.md),
            ..._outputRows(_parsed!),
          ] else
            const MqEmptyHint(label: 'Paste a timestamp to see all forms.'),
        ],
      ),
    );
  }

  static List<Widget> _outputRows(DateTime t) {
    final String utc = DateFormat('yyyy-MM-dd HH:mm:ss').format(t.toUtc());
    final String local = DateFormat('yyyy-MM-dd HH:mm:ss').format(t.toLocal());
    final int ms = t.millisecondsSinceEpoch;
    final int s = (ms / 1000).round();
    final List<({String label, String value, bool copyable})> rows =
        <({String label, String value, bool copyable})>[
          (label: 'UTC', value: utc, copyable: true),
          (label: 'Local', value: local, copyable: true),
          (label: 'Unix seconds', value: '$s', copyable: true),
          (label: 'Unix ms', value: '$ms', copyable: true),
          (
            label: 'ISO 8601',
            value: t.toUtc().toIso8601String(),
            copyable: true,
          ),
          (label: 'Relative', value: _relative(t), copyable: false),
        ];
    final List<Widget> widgets = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: MqSpacing.sm));
      widgets.add(
        MqMonoCell(
          label: rows[i].label,
          value: rows[i].value,
          copyable: rows[i].copyable,
        ),
      );
    }
    return widgets;
  }

  static String _formatLabel(TimestampFormat f) => switch (f) {
    TimestampFormat.unixSeconds => 'Unix seconds',
    TimestampFormat.unixMilliseconds => 'Unix ms',
    TimestampFormat.unixMicroseconds => 'Unix µs',
    TimestampFormat.unixNanoseconds => 'Unix ns',
    TimestampFormat.iso8601 => 'ISO 8601',
    TimestampFormat.keyword => 'Keyword',
    TimestampFormat.unknown => 'Unknown',
  };

  static String _relative(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    final int abs = d.inSeconds.abs();
    String suffix(int v, String unit) =>
        '$v $unit${v == 1 ? '' : 's'} ${d.isNegative ? 'from now' : 'ago'}';
    if (abs < 60) return suffix(abs, 'second');
    if (abs < 3600) return suffix(abs ~/ 60, 'minute');
    if (abs < 86400) return suffix(abs ~/ 3600, 'hour');
    if (abs < 30 * 86400) return suffix(abs ~/ 86400, 'day');
    return DateFormat('yyyy-MM-dd').format(t);
  }
}

/// Trailing icon button on the timestamp input that opens a modal
/// containing the three keyword select groups (anchor, modifier, unit).
class _KeywordPickerButton extends StatefulWidget {
  const _KeywordPickerButton({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<_KeywordPickerButton> createState() => _KeywordPickerButtonState();
}

class _KeywordPickerButtonState extends State<_KeywordPickerButton> {
  static const List<String> _anchors = <String>[
    'now',
    'today',
    'yesterday',
    'tomorrow',
  ];

  static const List<String> _units = <String>[
    'second',
    'minute',
    'hour',
    'day',
    'week',
    'month',
    'year',
  ];

  static const List<String> _modifiers = <String>['last', 'this', 'next'];

  String _modifier = 'this';
  String _unit = 'hour';

  Future<String?> _pickFromSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    String? selected,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: <Widget>[
          for (final String o in options)
            CupertinoActionSheetAction(
              isDefaultAction: o == selected,
              onPressed: () => Navigator.of(ctx).pop(o),
              child: Text(o),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickAnchor(BuildContext context) async {
    final String? choice = await _pickFromSheet(
      context,
      title: 'Anchor',
      options: _anchors,
    );
    if (choice != null) widget.onPick(choice);
  }

  Future<void> _pickPair({
    required BuildContext sheetCtx,
    required StateSetter setSheetState,
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> assign,
  }) async {
    final String? choice = await _pickFromSheet(
      sheetCtx,
      title: title,
      options: options,
      selected: current,
    );
    if (choice == null) return;
    assign(choice);
    setSheetState(() {});
    widget.onPick('$_modifier $_unit');
  }

  Future<void> _open(BuildContext rootContext) async {
    await showCupertinoModalPopup<void>(
      context: rootContext,
      builder: (BuildContext sheetCtx) {
        final c = rootContext.mq.colors;
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, MqSpacing.sm),
                    child: Text(
                      'Insert keyword',
                      style: MqTextStyles.title3.copyWith(color: c.textPri),
                    ),
                  ),
                  _SelectRow(
                    label: 'Anchor',
                    value: 'now / today / yesterday / tomorrow',
                    onTap: () => _pickAnchor(sheetCtx),
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  StatefulBuilder(
                    builder: (BuildContext ctx, StateSetter setSheetState) =>
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _SelectRow(
                                label: 'Relative',
                                value: _modifier,
                                onTap: () => _pickPair(
                                  sheetCtx: sheetCtx,
                                  setSheetState: setSheetState,
                                  title: 'Relative',
                                  options: _modifiers,
                                  current: _modifier,
                                  assign: (String v) => _modifier = v,
                                ),
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: _SelectRow(
                                label: 'Unit',
                                value: _unit,
                                onTap: () => _pickPair(
                                  sheetCtx: sheetCtx,
                                  setSheetState: setSheetState,
                                  title: 'Unit',
                                  options: _units,
                                  current: _unit,
                                  assign: (String v) => _unit = v,
                                ),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqButton(
                    label: 'Done',
                    variant: MqButtonVariant.tinted,
                    full: true,
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Semantics(
        button: true,
        label: 'Insert keyword',
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(MqIcons.clock, size: 18, color: c.textSec),
        ),
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// When true, stacks label above value (no fixed gutter) so the row
  /// fits comfortably at half-width inside a side-by-side pair.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Widget labelText = Text(
      label,
      style: MqTextStyles.caption1.copyWith(color: c.textSec),
    );
    final Widget valueRow = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            value,
            style: MqTextStyles.subhead.copyWith(color: c.textPri),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(MqIcons.chevD, size: 14, color: c.textTer),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MqSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.md,
        ),
        radius: MqRadius.md,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  labelText,
                  const SizedBox(height: MqSpacing.xs),
                  valueRow,
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 72, child: labelText),
                  Expanded(child: valueRow),
                ],
              ),
      ),
    );
  }
}
