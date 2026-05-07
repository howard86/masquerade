import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/color_parser.dart';
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

class ColorBody extends StatefulWidget {
  const ColorBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;

  @override
  State<ColorBody> createState() => _ColorBodyState();
}

class _ColorBodyState extends State<ColorBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  MqColorValue? _value;
  String? _error;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    _controller.text = (seed != null && seed.isNotEmpty) ? seed : '#00B8C4';
    _value = MqColorParser.parse(_controller.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'color',
      );
      if (widget.seedSource == SeedSource.paste) {
        _recorder!.markPaste();
      }
      // Auto-record only when the host actually handed us a seed. The cold
      // default (#00B8C4) is just placeholder UI — recording it on every
      // open would spam history with duplicate entries.
      final String? seed = widget.initialInput;
      if (seed != null && seed.isNotEmpty && _value != null) {
        // Notifying HistoryController during build would trip the
        // "setState during build" assertion via HistoryScope, so defer.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recorder?.record(_controller.text, _value!.hex);
        });
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
      _recorder?.record(input, parsed.hex);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Color',
          placeholder: '#00B8C4, rgb(0,184,196), hsl(184,100%,38%)',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
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
          const MqSectionHeader(label: 'Output'),
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
          OpenInFooter(
            output: _value?.hex,
            excludeUtilityId: 'color',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(label: 'Paste a color to inspect.'),
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
        borderRadius: BorderRadius.circular(MqRadius.md),
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
