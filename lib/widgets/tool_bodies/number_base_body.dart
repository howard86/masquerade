import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../utils/history_recorder.dart';
import '../../utils/number_base_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import 'seed_source.dart';

class NumberBaseBody extends StatefulWidget {
  const NumberBaseBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
  });

  final String? initialInput;
  final SeedSource seedSource;

  @override
  State<NumberBaseBody> createState() => _NumberBaseBodyState();
}

class _NumberBaseBodyState extends State<NumberBaseBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  NumberBaseResult? _result;
  String? _error;

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
        utilityId: 'number_base',
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
      _recorder?.record(input, parsed.decimal);
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _recorder?.markPaste();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: '0xFF, 0b1010, 255, 0o377…',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
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
          const MqEmptyHint(label: 'Paste a number to convert across bases.'),
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
