import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import '../../utils/bps_parser.dart';
import '../../widgets/mb/mb_button.dart';
import '../../widgets/mb/mb_icons.dart';
import '../../widgets/mb/mb_input.dart';
import '../../widgets/mb/mb_mono_cell.dart';
import '../../widgets/mb/mb_section_header.dart';
import '../../widgets/mb/mb_status.dart';
import 'detail_scaffold.dart';

class BpsScreen extends StatefulWidget {
  const BpsScreen({super.key});

  @override
  State<BpsScreen> createState() => _BpsScreenState();
}

class _BpsScreenState extends State<BpsScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BpsResult? _result;
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
    final c = context.mb.colors;
    return MBDetailScaffold(
      title: 'bps · % · decimal',
      subtitle: 'Auto-detect. All three shown. Reference-only.',
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
            placeholder: '25 bps · 0.25% · 0.0025',
            onChanged: _onChanged,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          const SizedBox(height: MBSpacing.lg),
          if (_error != null)
            MBMonoCell(label: 'Error', value: _error!, copyable: false)
          else if (_result != null) ...<Widget>[
            const MBSectionHeader(label: 'Detected'),
            MBStatus(label: _result!.detected.name, kind: MBStatusKind.info),
            const SizedBox(height: MBSpacing.md),
            const MBSectionHeader(label: 'All forms'),
            MBMonoCell(
              label: 'Basis points',
              value: _result!.bps.toStringAsFixed(2),
              accent: true,
              large: true,
            ),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(
              label: 'Percent',
              value: '${_result!.percent.toStringAsFixed(4)}%',
            ),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(
              label: 'Decimal',
              value: _result!.decimal.toStringAsFixed(6),
            ),
            const SizedBox(height: MBSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Reference only. Not financial advice. Annualization is implementation-dependent.',
                style: MBTextStyles.caption1.copyWith(color: c.textTer),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MBSpacing.lg),
              child: Text(
                'Enter a value with bps, % or decimal.',
                style: MBTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
