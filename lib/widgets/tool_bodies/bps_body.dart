import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/bps_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import 'seed_source.dart';

class BpsBody extends StatefulWidget {
  const BpsBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
  });

  final String? initialInput;
  final SeedSource seedSource;

  @override
  State<BpsBody> createState() => _BpsBodyState();
}

class _BpsBodyState extends State<BpsBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BpsResult? _result;
  String? _error;

  late final HistoryRecorder _recorder;
  bool _recorderInited = false;
  bool _nextWriteIsPaste = false;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      _nextWriteIsPaste = widget.seedSource == SeedSource.paste;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parse();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recorderInited) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'bps',
      );
      _recorderInited = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_recorderInited) _recorder.dispose();
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
        _result = null;
        _error = null;
      });
      return;
    }
    final BpsResult? parsed = BpsParser.parse(input);
    setState(() {
      _result = parsed;
      _error = parsed == null ? 'Could not parse as bps, % or decimal.' : null;
    });
    if (parsed != null) {
      _record(input, '${parsed.bps.toStringAsFixed(2)} bps');
    }
  }

  void _record(String input, String output) {
    if (_nextWriteIsPaste) {
      _recorder.recordPaste(input, output);
      _nextWriteIsPaste = false;
    } else {
      _recorder.recordTyping(input, output);
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _nextWriteIsPaste = true;
    _parse();
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: '25 bps · 0.25% · 0.0025',
          onChanged: _onChanged,
          onPaste: (_) => _nextWriteIsPaste = true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null)
          MqMonoCell(label: 'Error', value: _error!, copyable: false)
        else if (_result != null) ...<Widget>[
          const MqSectionHeader(label: 'Detected'),
          MqStatus(label: _result!.detected.name, kind: MqStatusKind.info),
          const SizedBox(height: MqSpacing.md),
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: 'Basis points',
            value: _result!.bps.toStringAsFixed(2),
            accent: true,
            large: true,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Percent',
            value: '${_result!.percent.toStringAsFixed(4)}%',
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Decimal',
            value: _result!.decimal.toStringAsFixed(6),
          ),
          const SizedBox(height: MqSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Reference only. Not financial advice. Annualization is implementation-dependent.',
              style: MqTextStyles.caption1.copyWith(color: c.textTer),
            ),
          ),
        ] else
          const MqEmptyHint(label: 'Paste a value with bps, % or decimal.'),
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
}
