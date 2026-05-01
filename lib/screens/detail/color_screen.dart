import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/color_parser.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_status.dart';
import 'detail_scaffold.dart';

class ColorScreen extends StatefulWidget {
  const ColorScreen({super.key});

  @override
  State<ColorScreen> createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {
  final TextEditingController _controller = TextEditingController(
    text: '#00B8C4',
  );
  Timer? _debounce;
  MqColorValue? _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _value = MqColorParser.parse(_controller.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _value != null) {
        HistoryScope.of(context).add(
          HistoryEntry(
            utilityId: 'color',
            input: _controller.text,
            output: _value!.hex,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
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
        _value = null;
        _error = null;
      });
      return;
    }
    final MqColorValue? parsed = MqColorParser.parse(input);
    setState(() {
      _value = parsed;
      _error = parsed == null
          ? 'Could not parse color. Try #RRGGBB, rgb(), hsl().'
          : null;
    });
    if (parsed != null) {
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'color',
          input: input,
          output: parsed.hex,
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
      _value = null;
      _error = null;
    });
  }

  MqStatusKind _contrastKind(double ratio) {
    if (ratio >= 4.5) return MqStatusKind.success;
    if (ratio >= 3.0) return MqStatusKind.warning;
    return MqStatusKind.danger;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    return MqDetailScaffold(
      title: 'Color',
      subtitle: 'Hero swatch. HEX/RGB/HSL/OKLCH. WCAG contrast.',
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
            label: 'Color',
            placeholder: '#00B8C4, rgb(0,184,196), hsl(184,100%,38%)',
            onChanged: _onChanged,
          ),
          const SizedBox(height: MqSpacing.lg),
          if (_error != null)
            MqMonoCell(label: 'Error', value: _error!, copyable: false)
          else if (_value != null) ...<Widget>[
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: _value!.toFlutter,
                borderRadius: BorderRadius.circular(MqRadius.lg),
                border: Border.all(color: c.border, width: 0.5),
              ),
            ),
            const SizedBox(height: MqSpacing.lg),
            const MqSectionHeader(label: 'Forms'),
            MqMonoCell(label: 'HEX', value: _value!.hex, accent: true),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'RGB', value: _value!.rgb),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'HSL', value: _value!.hsl),
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'OKLCH', value: _value!.oklch),
            const SizedBox(height: MqSpacing.lg),
            const MqSectionHeader(label: 'WCAG contrast'),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ContrastRow(
                    label: 'vs white',
                    ratio: _value!.contrastRatioAgainst(
                      const MqColorValue(r: 255, g: 255, b: 255),
                    ),
                    kindFn: _contrastKind,
                  ),
                ),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: _ContrastRow(
                    label: 'vs black',
                    ratio: _value!.contrastRatioAgainst(
                      const MqColorValue(r: 0, g: 0, b: 0),
                    ),
                    kindFn: _contrastKind,
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
              child: Text(
                'Enter a color to inspect.',
                style: MqTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  const _ContrastRow({
    required this.label,
    required this.ratio,
    required this.kindFn,
  });
  final String label;
  final double ratio;
  final MqStatusKind Function(double) kindFn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: context.mq.colors.surface2,
        borderRadius: BorderRadius.circular(MqRadius.md - 2),
        border: Border.all(color: context.mq.colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: MqTextStyles.sectionLabel.copyWith(
              color: context.mq.colors.textSec,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ratio.toStringAsFixed(2)} : 1',
            style: MqTextStyles.monoLg.copyWith(
              color: context.mq.colors.textPri,
            ),
          ),
          const SizedBox(height: 6),
          MqStatus(
            label: ratio >= 4.5
                ? 'AA'
                : ratio >= 3.0
                ? 'AA Large'
                : 'Fail',
            kind: kindFn(ratio),
          ),
        ],
      ),
    );
  }
}
