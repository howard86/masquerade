import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/bps_parser.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_status.dart';
import 'detail_scaffold.dart';

class BpsScreen extends StatefulWidget {
  const BpsScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  State<BpsScreen> createState() => _BpsScreenState();
}

class _BpsScreenState extends State<BpsScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BpsResult? _result;
  String? _error;

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
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'bps',
          input: input,
          output: '${parsed.bps.toStringAsFixed(2)} bps',
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
    _controller.clear();
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return MqDetailScaffold(
      title: 'bps · % · decimal',
      subtitle: 'Auto-detect. All three shown. Reference-only.',
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
            placeholder: '25 bps · 0.25% · 0.0025',
            onChanged: _onChanged,
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
            const MqSectionHeader(label: 'All forms'),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
              child: Text(
                'Enter a value with bps, % or decimal.',
                style: MqTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
