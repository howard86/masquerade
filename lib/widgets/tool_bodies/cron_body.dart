import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/cron_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class CronBody extends StatefulWidget {
  const CronBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: '0 9 * * 1   ·   every weekday at 9am   ·   @daily',
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
          OpenInFooter(
            output: _firstNextRunIso(),
            excludeUtilityId: 'cron',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(
            label: 'Paste cron syntax or describe a schedule in English.',
          ),
        const SizedBox(height: MqSpacing.lg),
        Row(
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
