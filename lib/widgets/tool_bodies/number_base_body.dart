import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/number_base_parser.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_layout.dart';

class NumberBaseBody extends StatefulWidget {
  const NumberBaseBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  /// Non-null when this card is in a canvas Link group. The group's canonical
  /// value is the parsed number as a decimal string; this body projects it
  /// across bases and parses local edits back to a decimal (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<NumberBaseBody> createState() => _NumberBaseBodyState();
}

class _NumberBaseBodyState extends State<NumberBaseBody>
    with LinkableToolBody<NumberBaseBody> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
    });
    initLink();
  }

  @override
  void didUpdateWidget(NumberBaseBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (decimal-number canonical) ──────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical is the parsed value as a plain decimal string — empty until
  /// something parses, so a number ↔ math link shares one numeric value.
  @override
  String currentCanonical() => _result?.decimal ?? '';

  @override
  void applyInbound(String canonical) {
    // The parser accepts a bare decimal, so re-projecting [canonical] as the
    // input round-trips back to the same decimal through [_parse].
    _controller.text = canonical;
    _parse();
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
    disposeLink();
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
      emitToLink();
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
    emitToLink();
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

  /// Re-feeds [value] as a plain decimal through the normal parse/emit path so
  /// the bit grid stays a thin editor over the existing pipeline.
  void _setValue(BigInt value) {
    _debounce?.cancel();
    _controller.text = value.toString();
    _parse();
  }

  // TODO(phase7): ⇧↑↓ nibble-nudge keyboard accelerator over the bit grid.

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kToolCanvasWide;
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
                // Canvas-only: the decimal is the number canonical, draggable to
                // a Math card. Inert on mobile (no PipeScope ancestor).
                pipeType: ContentType.number,
              ),
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(label: 'Hexadecimal', value: _result!.hex),
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(label: 'Octal', value: _result!.octal),
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(label: 'Binary', value: _result!.binary),
              // Canvas-only: an interactive bit grid for the current value,
              // default-expanded. Hidden on phones (width < [kToolCanvasWide]),
              // where the body stays exactly as before.
              if (wide && _result!.value.sign >= 0) ...<Widget>[
                const SizedBox(height: MqSpacing.md),
                const MqSectionHeader(label: 'Bits'),
                _BitGrid(value: _result!.value, onChanged: _setValue),
              ],
              OpenInFooter(
                output: _result?.decimal,
                excludeUtilityId: 'number_base',
                onSwitchTool: widget.onSwitchTool,
              ),
            ] else
              const MqEmptyHint(
                label: 'Paste a number to convert across bases.',
              ),
          ],
        );
      },
    );
  }
}

/// Interactive bit grid for a non-negative [value]. Renders enough nibbles to
/// hold the value (minimum one byte), each bit a toggleable cell labelled with
/// its index. Tapping a bit flips it and re-emits the new value to the parent.
class _BitGrid extends StatelessWidget {
  const _BitGrid({required this.value, required this.onChanged});

  final BigInt value;
  final ValueChanged<BigInt> onChanged;

  @override
  Widget build(BuildContext context) {
    // Round up to a whole nibble; show at least 8 bits so a small value still
    // reads as a byte. Cap at 64 bits to keep the grid bounded for huge inputs.
    final int bitLength = value.bitLength;
    int nibbles = ((bitLength + 3) ~/ 4).clamp(2, 16);
    final int bits = nibbles * 4;
    return Wrap(
      spacing: MqSpacing.sm,
      runSpacing: MqSpacing.sm,
      children: <Widget>[
        for (int n = 0; n < nibbles; n++)
          _Nibble(
            value: value,
            highBit: bits - 1 - n * 4,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

/// A group of four adjacent bits (one nibble), MSB first.
class _Nibble extends StatelessWidget {
  const _Nibble({
    required this.value,
    required this.highBit,
    required this.onChanged,
  });

  final BigInt value;
  final int highBit;
  final ValueChanged<BigInt> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 2),
          _BitCell(
            index: highBit - i,
            on: (value >> (highBit - i)) & BigInt.one == BigInt.one,
            onTap: () => onChanged(value ^ (BigInt.one << (highBit - i))),
          ),
        ],
      ],
    );
  }
}

/// A single toggleable bit cell: bit value above its index.
class _BitCell extends StatelessWidget {
  const _BitCell({required this.index, required this.on, required this.onTap});

  final int index;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Semantics(
      button: true,
      label: 'Bit $index ${on ? 'set' : 'clear'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: on ? c.accentBg : c.monoBg,
            borderRadius: BorderRadius.circular(MqRadius.sm),
            border: Border.all(color: on ? c.accent : c.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                on ? '1' : '0',
                style: MqTextStyles.monoMd.copyWith(
                  color: on ? c.accent : c.textTer,
                ),
              ),
              Text(
                '$index',
                style: MqTextStyles.caption1.copyWith(
                  color: c.textTer,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
