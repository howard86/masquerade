import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import '../../utils/number_base_parser.dart';
import '../../widgets/mb/mb_button.dart';
import '../../widgets/mb/mb_icons.dart';
import '../../widgets/mb/mb_input.dart';
import '../../widgets/mb/mb_mono_cell.dart';
import '../../widgets/mb/mb_section_header.dart';
import '../../widgets/mb/mb_status.dart';
import 'detail_scaffold.dart';

class NumberBaseScreen extends StatefulWidget {
  const NumberBaseScreen({super.key});

  @override
  State<NumberBaseScreen> createState() => _NumberBaseScreenState();
}

class _NumberBaseScreenState extends State<NumberBaseScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  NumberBaseResult? _result;
  String? _error;

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
    final c = context.mb.colors;
    return MBDetailScaffold(
      title: 'Number Base',
      subtitle: 'Auto-detect base. All forms shown live.',
      bottomBar: Row(
        children: <Widget>[
          Expanded(
            child: MBButton(
              label: 'Paste',
              icon: MBIcons.paste,
              variant: MBButtonVariant.glass,
              onPressed: _paste,
              full: true,
            ),
          ),
          const SizedBox(width: MBSpacing.sm),
          Expanded(
            child: MBButton(
              label: 'Clear',
              icon: MBIcons.clear,
              variant: MBButtonVariant.glass,
              onPressed: _clear,
              full: true,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MBInput(
            controller: _controller,
            label: 'Input',
            placeholder: '0xFF, 0b1010, 255, 0o377…',
            onChanged: _onChanged,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: MBSpacing.lg),
          if (_error != null)
            MBMonoCell(label: 'Error', value: _error!, copyable: false)
          else if (_result != null) ...<Widget>[
            const MBSectionHeader(label: 'Detected base'),
            MBStatus(
              label: 'Base ${_result!.detectedBase}',
              kind: MBStatusKind.info,
            ),
            const SizedBox(height: MBSpacing.md),
            const MBSectionHeader(label: 'All forms'),
            MBMonoCell(
              label: 'Decimal',
              value: _result!.decimal,
              large: true,
              accent: true,
            ),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'Hexadecimal', value: _result!.hex),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'Octal', value: _result!.octal),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'Binary', value: _result!.binary),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MBSpacing.lg),
              child: Text(
                'Enter a number to convert across bases.',
                style: MBTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
