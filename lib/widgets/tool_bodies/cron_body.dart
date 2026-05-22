import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/cron_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_layout.dart';

class CronBody extends StatefulWidget {
  const CronBody({
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
  State<CronBody> createState() => _CronBodyState();
}

class _CronBodyState extends State<CronBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  CronSchedule? _schedule;
  CronParsedMode? _mode;
  String? _error;

  /// Frozen reference time at parse — ensures next-run rows don't tick.
  DateTime? _referenceNow;

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
        utilityId: 'cron',
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

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _parse);
  }

  void _parse() {
    final String input = _controller.text;
    if (input.trim().isEmpty) {
      setState(() {
        _schedule = null;
        _mode = null;
        _error = null;
        _referenceNow = null;
      });
      return;
    }
    final CronParseResult r = CronParser.parse(input);
    setState(() {
      _schedule = r.schedule;
      _mode = r.mode;
      _referenceNow = r.isSuccess ? DateTime.now() : null;
      _error = r.isSuccess ? null : _buildErrorMessage(r);
    });
    if (r.isSuccess) {
      _recorder?.record(input, r.schedule!.canonical);
    }
  }

  static final RegExp _cronShapeRe = RegExp(r'^[\d*@]');

  String _buildErrorMessage(CronParseResult r) {
    final String trimmed = _controller.text.trim();
    final bool looksCron = trimmed.isNotEmpty && _cronShapeRe.hasMatch(trimmed);
    if (looksCron && r.cronError != null) return r.cronError!;
    if (r.nlError != null) return r.nlError!;
    return r.cronError ?? 'Could not parse as cron or natural language.';
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
      _schedule = null;
      _mode = null;
      _error = null;
      _referenceNow = null;
    });
  }

  String? _firstNextRunIso() {
    final CronSchedule? s = _schedule;
    final DateTime? from = _referenceNow;
    if (s == null || from == null) return null;
    final Iterable<DateTime> runs = s.nextRuns(from, count: 1);
    if (runs.isEmpty) return null;
    return runs.first.toUtc().toIso8601String();
  }

  /// Upcoming local fire times within the next 7 days. Pulls a generous run
  /// budget from [CronSchedule.nextRuns] then trims to the 7-day window — a
  /// high-frequency schedule (e.g. every minute) would otherwise produce
  /// thousands, so the budget caps the strip.
  List<DateTime> _firesWithin7Days(CronSchedule s, DateTime from) {
    final DateTime cutoff = from.add(const Duration(days: 7));
    return s
        .nextRuns(from, count: 200)
        .where((DateTime t) => t.isBefore(cutoff))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: '*/5 * * * *',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
          multiline: true,
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null)
          MqMonoCell(label: 'Error', value: _error!, copyable: false)
        else if (_schedule != null && _referenceNow != null) ...<Widget>[
          const MqSectionHeader(label: 'Detected'),
          MqStatus(
            label: _mode == CronParsedMode.naturalLanguage
                ? 'Natural language'
                : 'Cron',
            kind: MqStatusKind.info,
          ),
          const SizedBox(height: MqSpacing.md),
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: 'Cron',
            value: _schedule!.canonical,
            accent: true,
            large: true,
          ),
          if (_schedule!.macro != null) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'Macro', value: _schedule!.macro!),
          ],
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Description',
            value: _schedule!.description,
            copyable: false,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Fields',
            value: _renderFields(_schedule!),
            copyable: false,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Next 5 (local)',
            value: _renderNextRuns(_schedule!, _referenceNow!),
            copyable: true,
          ),
          // Canvas-wide: a compact horizontal strip of every fire in the next
          // 7 days. Below 460 this is absent — mobile parity (the Next 5 cell
          // already covers upcoming runs).
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < kToolCanvasWide) {
                return const SizedBox.shrink();
              }
              return _FireStrip(
                fires: _firesWithin7Days(_schedule!, _referenceNow!),
              );
            },
          ),
          OpenInFooter(
            output: _firstNextRunIso(),
            excludeUtilityId: 'cron',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(
            label: 'Paste cron syntax or describe a schedule in English.',
          ),
      ],
    );
  }

  static String _renderFields(CronSchedule s) =>
      'minute=${s.minute.render()}  '
      'hour=${s.hour.render()}  '
      'day=${s.dayOfMonth.render()}  '
      'month=${s.month.render()}  '
      'weekday=${s.dayOfWeek.render()}';

  static String _renderNextRuns(CronSchedule s, DateTime from) {
    final List<DateTime> runs = s.nextRuns(from, count: 5).toList();
    if (runs.isEmpty) return 'No upcoming runs.';
    final DateFormat fmt = DateFormat('yyyy-MM-dd HH:mm (EEE)');
    return runs.map((DateTime t) => fmt.format(t.toLocal())).join('\n');
  }
}

/// Canvas-wide 7-day fire strip: every upcoming fire in the next week as a
/// compact, horizontally-scrolling row of day/time tiles.
class _FireStrip extends StatelessWidget {
  const _FireStrip({required this.fires});

  final List<DateTime> fires;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding: const EdgeInsets.only(top: MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MqSectionHeader(label: 'Next 7 days'),
          if (fires.isEmpty)
            Text(
              'No fires in the next 7 days.',
              style: MqTextStyles.caption1.copyWith(color: c.textTer),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final DateTime t in fires) _FireTile(time: t.toLocal()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FireTile extends StatelessWidget {
  const _FireTile({required this.time});

  final DateTime time;

  static final DateFormat _day = DateFormat('EEE');
  static final DateFormat _date = DateFormat('MMM d');
  static final DateFormat _hm = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Padding(
      padding: const EdgeInsets.only(right: MqSpacing.sm),
      child: MqSurface(
        radius: MqRadius.sm,
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _day.format(time),
              style: MqTextStyles.caption2.copyWith(color: c.textTer),
            ),
            Text(
              _date.format(time),
              style: MqTextStyles.subhead.copyWith(color: c.textPri),
            ),
            const SizedBox(height: 2),
            Text(
              _hm.format(time),
              style: MqTextStyles.monoSm.copyWith(color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
