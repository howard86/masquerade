import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/number_base_parser.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_status.dart';
import 'detail_scaffold.dart';

class NumberBaseScreen extends StatefulWidget {
  const NumberBaseScreen({super.key, this.initialInput});

  final String? initialInput;

  @override
  State<NumberBaseScreen> createState() => _NumberBaseScreenState();
}

class _NumberBaseScreenState extends State<NumberBaseScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  NumberBaseResult? _result;
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
    final NumberBaseResult? parsed = NumberBaseParser.parse(input);
    setState(() {
      _result = parsed;
      _error = parsed == null
          ? 'Could not parse as a number in any base.'
          : null;
    });
    if (parsed != null) {
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'number_base',
          input: input,
          output: parsed.decimal,
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
      title: 'Number Base',
      subtitle: 'Auto-detect base. All forms shown live.',
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
            placeholder: '0xFF, 0b1010, 255, 0o377…',
            onChanged: _onChanged,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: MqSpacing.lg),
          if (_error != null)
            MqMonoCell(label: 'Error', value: _error!, copyable: false)
          else if (_result != null) ...<Widget>[
            const MqSectionHeader(label: 'Detected base'),
            MqStatus(
              label: 'Base ${_result!.detectedBase}',
              kind: MqStatusKind.info,
            ),
            const SizedBox(height: MqSpacing.md),
            const MqSectionHeader(label: 'Output'),
            MqMonoCell(
              label: 'Decimal',
              value: _result!.decimal,
              large: true,
              accent: true,
            ),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'Hexadecimal', value: _result!.hex),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'Octal', value: _result!.octal),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'Binary', value: _result!.binary),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
              child: Text(
                'Paste a number to convert across bases.',
                style: MqTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
