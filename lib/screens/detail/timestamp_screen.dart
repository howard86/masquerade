import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/timestamp_parser.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_status.dart';
import '../../widgets/timestamp_display_card.dart';
import 'detail_scaffold.dart';

class TimestampScreen extends StatefulWidget {
  const TimestampScreen({super.key});

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
      });
      return;
    }
    final TimestampParseResult result = TimestampParser.parseAnyFormat(input);
    bool ambiguous = false;
    final int? n = int.tryParse(input);
    if (n != null && n > 1_000_000_000 && n < 1_000_000_000_000) {
      // Range where seconds + ms interpretations both land in plausible dates.
      ambiguous = false;
    }
    setState(() {
      _parsed = result.timestamp;
      _format = result.format;
      _ambiguous = ambiguous;
      _error = result.isSuccess
          ? null
          : 'Invalid input format. Supported formats:\n'
                '• Unix timestamp (seconds/milliseconds)\n'
                '• ISO 8601 date format\n'
                '• Base64 encoded strings\n'
                '• Hex encoded strings';
    });
    if (result.isSuccess) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
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
            placeholder: 'Enter timestamp (Unix, ISO 8601, Base64, or Hex)',
            onChanged: _onChanged,
            multiline: true,
            minLines: 1,
            maxLines: 3,
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
            const MqSectionHeader(label: 'Detected'),
            Row(
              children: <Widget>[
                MqStatus(label: _formatLabel(_format), kind: MqStatusKind.info),
                if (_ambiguous) ...<Widget>[
                  const SizedBox(width: MqSpacing.sm),
                  const MqStatus(
                    label: 'Ambiguous',
                    kind: MqStatusKind.warning,
                  ),
                ],
              ],
            ),
            const SizedBox(height: MqSpacing.md),
            TimestampDisplayCard(timestamp: _parsed!),
            const SizedBox(height: MqSpacing.md),
            MqMonoCell(
              label: 'ISO 8601',
              value: _parsed!.toUtc().toIso8601String(),
            ),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(
              label: 'Relative',
              value: _relative(_parsed!),
              copyable: false,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
              child: Text(
                'Enter a timestamp to see all forms.',
                style: MqTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatLabel(TimestampFormat f) => switch (f) {
    TimestampFormat.unixSeconds => 'Unix seconds',
    TimestampFormat.unixMilliseconds => 'Unix ms',
    TimestampFormat.iso8601 => 'ISO 8601',
    TimestampFormat.base64 => 'Base64',
    TimestampFormat.hex => 'Hex',
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
