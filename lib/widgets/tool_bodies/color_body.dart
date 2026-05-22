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
import '../../utils/color_parser.dart';
import '../../utils/history_recorder.dart';
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

class ColorBody extends StatefulWidget {
  const ColorBody({
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
  /// value is the parsed canonical hex (`#RRGGBB`); this body projects it to
  /// every color form and parses a dropped hex back (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<ColorBody> createState() => _ColorBodyState();
}

class _ColorBodyState extends State<ColorBody>
    with LinkableToolBody<ColorBody> {
  /// Most swatches the session palette strip keeps. Canvas-only; per card.
  static const int _paletteCap = 8;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  MqColorValue? _value;
  String? _error;

  /// Sticky swatches of colors parsed in this card this session, most-recent
  /// first. Shown only in the wide layout (canvas); ignored at phone width.
  final List<MqColorValue> _palette = <MqColorValue>[];

  /// The opening field is a cold placeholder (`#00B8C4`) unless the host handed
  /// a seed. We must not let that placeholder seed a Link group it joins (it
  /// would clobber an existing canonical), so a fresh card pulls instead of
  /// emits on attach until the user actually provides a value.
  bool _userProvided = false;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    final bool hasSeed = seed != null && seed.isNotEmpty;
    _userProvided = hasSeed;
    _controller.text = hasSeed ? seed : '#00B8C4';
    _value = MqColorParser.parse(_controller.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
    });
    initLink();
  }

  @override
  void didUpdateWidget(ColorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (canonical-hex canonical) ───────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical is the parsed canonical hex. Empty until the user supplies a
  /// value, so an untouched card with the cold placeholder pulls the group's
  /// existing color rather than overwriting it with the placeholder.
  @override
  String currentCanonical() => _userProvided ? (_value?.hex ?? '') : '';

  @override
  void applyInbound(String canonical) {
    _userProvided = true;
    _controller.text = canonical;
    _parse();
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
    disposeLink();
    _debounce?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _userProvided = true;
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
      emitToLink();
      return;
    }
    final MqColorValue? parsed = MqColorParser.parse(input);
    setState(() {
      _value = parsed;
      _error = parsed == null
          ? 'Could not parse color. Try #RRGGBB, rgb(), hsl().'
          : null;
      if (parsed != null) _pushPalette(parsed);
    });
    if (parsed != null) {
      _recorder?.record(input, parsed.hex);
    }
    emitToLink();
  }

  /// Records [color] at the head of the session palette, deduping by hex and
  /// capping at [_paletteCap]. Always called inside a [setState].
  void _pushPalette(MqColorValue color) {
    _palette.removeWhere((MqColorValue c) => c.hex == color.hex);
    _palette.insert(0, color);
    if (_palette.length > _paletteCap) _palette.removeLast();
  }

  void _loadSwatch(MqColorValue color) {
    _userProvided = true;
    _controller.text = color.hex;
    _parse();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _userProvided = true;
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kToolCanvasWide;
        return _buildBody(context, wide);
      },
    );
  }

  Widget _buildBody(BuildContext context, bool wide) {
    final tokens = context.mq;
    final c = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Color',
          placeholder: '#00B8C4 or rgb(0,184,196)',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
        ),
        // Canvas-only: sticky swatches of colors entered this session; tap to
        // reload. Hidden at phone width so the body matches mobile exactly.
        if (wide && _palette.isNotEmpty) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          _PaletteStrip(swatches: _palette, onTap: _loadSwatch),
        ],
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
          MqMonoCell(
            label: 'HEX',
            value: _value!.hex,
            accent: true,
            // Canvas-only: the canonical hex is draggable as both the color and
            // text canonical. Inert on mobile (no PipeScope ancestor).
            pipeType: ContentType.color,
          ),
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
      ],
    );
  }
}

/// Horizontal row of tappable session swatches (most-recent first). Wraps so a
/// full palette never overflows under large Dynamic Type.
class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({required this.swatches, required this.onTap});

  final List<MqColorValue> swatches;
  final ValueChanged<MqColorValue> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Wrap(
      spacing: MqSpacing.sm,
      runSpacing: MqSpacing.sm,
      children: <Widget>[
        for (final MqColorValue color in swatches)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.toFlutter,
                borderRadius: BorderRadius.circular(MqRadius.sm),
                border: Border.all(color: c.border, width: 0.5),
              ),
            ),
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
