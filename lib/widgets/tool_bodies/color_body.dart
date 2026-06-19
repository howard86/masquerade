import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/color_parser.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'copy_all_button.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';
import 'tool_layout.dart';

class ColorBody extends StatefulWidget implements ToolBodyWidget {
  const ColorBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  @override
  final String? initialInput;
  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;

  /// Non-null when this card is in a canvas Link group. The group's canonical
  /// value is the parsed canonical hex (`#RRGGBB`); this body projects it to
  /// every color form and parses a dropped hex back (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<ColorBody> createState() => _ColorBodyState();
}

class _ColorBodyState extends State<ColorBody>
    with ToolBodyScaffold<ColorBody>, LinkableToolBody<ColorBody> {
  /// Most swatches the session palette strip keeps. Canvas-only; per card.
  static const int _paletteCap = 8;

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

  @override
  String get utilityId => 'color';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    // The scaffold seeds the controller from a real seed (and schedules its
    // parse). When there's no seed, fall back to the cold placeholder and parse
    // it synchronously so the swatch shows on the first frame. The placeholder
    // stays unrecorded and leaves [_userProvided] false.
    if (controller.text.isEmpty) {
      controller.text = '#00B8C4';
      _value = MqColorParser.parse(controller.text);
    }
  }

  @override
  void onSeed(String seed) {
    // A real seed counts as user-provided and is parsed synchronously so the
    // swatch is visible immediately; the scaffold's deferred parse re-runs and
    // records it.
    _userProvided = true;
    _value = MqColorParser.parse(seed);
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
    setInput(canonical, asPaste: false);
  }

  void _onChanged(String text) {
    _userProvided = true;
    onInputChanged(text);
  }

  @override
  void parse(String input) {
    final MqColorValue? parsed = MqColorParser.parse(input);
    setState(() {
      _value = parsed;
      _error = parsed == null
          ? 'Could not parse color. Try #RRGGBB, rgb(), hsl().'
          : null;
      if (parsed != null) _pushPalette(parsed);
    });
    if (parsed != null) {
      recordOutput(input, parsed.hex);
    }
    emitToLink();
  }

  @override
  void reset() {
    setState(() {
      _value = null;
      _error = null;
    });
    emitToLink();
  }

  /// Copies every color form (HEX/RGB/HSL/OKLCH) at once. Hidden until a color
  /// parses, so the action bar shows it only when there is output to copy.
  @override
  Widget? actionBarCenter() {
    final MqColorValue? v = _value;
    if (v == null) return null;
    return CopyAllButton(
      payload: <String>[v.hex, v.rgb, v.hsl, v.oklch].join('\n'),
    );
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
    setInput(color.hex, asPaste: false);
  }

  /// A clipboard paste counts as user-provided, so the parsed color can seed a
  /// Link group (the cold placeholder must not).
  @override
  Future<void> pasteFromClipboard() {
    _userProvided = true;
    return super.pasteFromClipboard();
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
          controller: controller,
          label: 'Color',
          placeholder: '#00B8C4 or rgb(0,184,196)',
          onChanged: _onChanged,
          onPaste: (_) => markPaste(),
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
