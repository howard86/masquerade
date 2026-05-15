import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/timestamp_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class TimestampBody extends StatefulWidget {
  const TimestampBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  @override
  State<TimestampBody> createState() => _TimestampBodyState();
}

class _TimestampBodyState extends State<TimestampBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  DateTime? _parsed;
  TimestampFormat _format = TimestampFormat.unknown;
  String? _error;
  bool _ambiguous = false;
  bool _naive = false;

  /// Non-null when the user has tapped the ambiguity banner to override the
  /// heuristic's default interpretation for the session. Cleared when input
  /// changes to something unambiguous.
  TimestampFormat? _forcedUnit;

  HistoryRecorder? _recorder;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'timestamp',
      );
      if (widget.seedSource == SeedSource.paste) {
        _recorder!.markPaste();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
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
        _forcedUnit = null;
      });
      return;
    }
    final TimestampParseResult heuristic = TimestampParser.parseAnyFormat(
      input,
    );
    final TimestampFormat? forced = heuristic.isAmbiguous ? _forcedUnit : null;
    final TimestampParseResult result = forced == null
        ? heuristic
        : TimestampParser.parseAs(input, forced);
    setState(() {
      _parsed = result.timestamp;
      _format = result.format;
      _ambiguous = heuristic.isAmbiguous;
      _naive = result.isNaive;
      if (!heuristic.isAmbiguous) _forcedUnit = null;
      _error = result.isSuccess
          ? null
          : 'Invalid input format. Supported formats:\n'
                '• Unix timestamp (seconds, ms, µs, or ns)\n'
                '• ISO 8601 date format\n'
                '• Keywords: now, today, yesterday, tomorrow,\n'
                '  or this/last/next + second/minute/hour/day/week/month/year';
    });
    if (result.isSuccess) {
      _recorder?.record(input, result.timestamp!.toIso8601String());
    }
  }

  void _toggleAmbiguousUnit() {
    HapticFeedback.selectionClick();
    final TimestampFormat current = _format == TimestampFormat.unixSeconds
        ? TimestampFormat.unixSeconds
        : TimestampFormat.unixMilliseconds;
    final TimestampFormat next = current == TimestampFormat.unixSeconds
        ? TimestampFormat.unixMilliseconds
        : TimestampFormat.unixSeconds;
    setState(() => _forcedUnit = next);
    _parse();
  }

  void _applyKeyword(String keyword) {
    _debounce?.cancel();
    _controller.text = keyword;
    _recorder?.markPaste();
    _parse();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _recorder?.markPaste();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder:
              'Enter timestamp (Unix s/ms/µs/ns, ISO 8601, or keyword)',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
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
              if (_naive)
                const MqStatus(
                  label: 'Local TZ assumed',
                  kind: MqStatusKind.warning,
                ),
            ],
          ),
          if (_ambiguous) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            _AmbiguityBanner(current: _format, onToggle: _toggleAmbiguousUnit),
          ],
          const SizedBox(height: MqSpacing.md),
          ..._outputRows(_parsed!),
          OpenInFooter(
            output: _parsed?.toUtc().toIso8601String(),
            excludeUtilityId: 'timestamp',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(label: 'Paste a timestamp to see all forms.'),
      ],
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

/// Full-width warning banner shown when an integer falls in the
/// seconds/ms overlap range. Tapping toggles the interpretation; the
/// timestamp body re-renders every derived row.
class _AmbiguityBanner extends StatelessWidget {
  const _AmbiguityBanner({required this.current, required this.onToggle});

  final TimestampFormat current;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final bool isSeconds = current == TimestampFormat.unixSeconds;
    final String currentLabel = isSeconds ? 'seconds' : 'milliseconds';
    final String otherLabel = isSeconds ? 'milliseconds' : 'seconds';
    return Semantics(
      button: true,
      label:
          'Ambiguous magnitude. Reading as $currentLabel. '
          'Double-tap to switch to $otherLabel.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: MqSurface(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.md,
          ),
          radius: MqRadius.sm,
          background: c.warningBg,
          borderColor: c.warning,
          child: Row(
            children: <Widget>[
              Icon(MqIcons.warn, size: 18, color: c.warning),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(
                  'Ambiguous — reading as $currentLabel. '
                  'Tap to switch to $otherLabel.',
                  style: MqTextStyles.subhead.copyWith(color: c.textPri),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
