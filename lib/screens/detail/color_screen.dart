import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import '../../utils/color_parser.dart';
import '../../widgets/mb/mb_button.dart';
import '../../widgets/mb/mb_icons.dart';
import '../../widgets/mb/mb_input.dart';
import '../../widgets/mb/mb_mono_cell.dart';
import '../../widgets/mb/mb_section_header.dart';
import '../../widgets/mb/mb_status.dart';
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
  MBColorValue? _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _value = MBColorParser.parse(_controller.text);
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
    final MBColorValue? parsed = MBColorParser.parse(input);
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

  MBStatusKind _contrastKind(double ratio) {
    if (ratio >= 4.5) return MBStatusKind.success;
    if (ratio >= 3.0) return MBStatusKind.warning;
    return MBStatusKind.danger;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    final c = tokens.colors;

    return MBDetailScaffold(
      title: 'Color',
      subtitle: 'Hero swatch. HEX/RGB/HSL/OKLCH. WCAG contrast.',
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
            label: 'Color',
            placeholder: '#00B8C4, rgb(0,184,196), hsl(184,100%,38%)',
            onChanged: _onChanged,
          ),
          const SizedBox(height: MBSpacing.lg),
          if (_error != null)
            MBMonoCell(label: 'Error', value: _error!, copyable: false)
          else if (_value != null) ...<Widget>[
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: _value!.toFlutter,
                borderRadius: BorderRadius.circular(MBRadius.lg),
                border: Border.all(color: c.border, width: 0.5),
              ),
            ),
            const SizedBox(height: MBSpacing.lg),
            const MBSectionHeader(label: 'Forms'),
            MBMonoCell(label: 'HEX', value: _value!.hex, accent: true),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'RGB', value: _value!.rgb),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'HSL', value: _value!.hsl),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(label: 'OKLCH', value: _value!.oklch),
            const SizedBox(height: MBSpacing.lg),
            const MBSectionHeader(label: 'WCAG contrast'),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ContrastRow(
                    label: 'vs white',
                    ratio: _value!.contrastRatioAgainst(
                      const MBColorValue(r: 255, g: 255, b: 255),
                    ),
                    kindFn: _contrastKind,
                  ),
                ),
                const SizedBox(width: MBSpacing.sm),
                Expanded(
                  child: _ContrastRow(
                    label: 'vs black',
                    ratio: _value!.contrastRatioAgainst(
                      const MBColorValue(r: 0, g: 0, b: 0),
                    ),
                    kindFn: _contrastKind,
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MBSpacing.lg),
              child: Text(
                'Enter a color to inspect.',
                style: MBTextStyles.subhead.copyWith(color: c.textTer),
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
  final MBStatusKind Function(double) kindFn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MBSpacing.md),
      decoration: BoxDecoration(
        color: context.mb.colors.surface2,
        borderRadius: BorderRadius.circular(MBRadius.md - 2),
        border: Border.all(color: context.mb.colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: MBTextStyles.sectionLabel.copyWith(
              color: context.mb.colors.textSec,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ratio.toStringAsFixed(2)} : 1',
            style: MBTextStyles.monoLg.copyWith(
              color: context.mb.colors.textPri,
            ),
          ),
          const SizedBox(height: 6),
          MBStatus(
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
