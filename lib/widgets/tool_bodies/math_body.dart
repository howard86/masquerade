import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rational/rational.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/math_parser.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_layout.dart';

class MathBody extends StatefulWidget {
  const MathBody({
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
  /// value is a plain number (number ↔ math, or epoch ↔ math — Math treats an
  /// epoch as just a number): this body projects it to its result and parses a
  /// dropped number into a literal expression (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<MathBody> createState() => _MathBodyState();
}

class _MathBodyState extends State<MathBody> with LinkableToolBody<MathBody> {
  static const String _angleUnitPrefsKey = 'mq.math.angle_unit';

  /// Most evaluations the visible tape keeps in memory before dropping the
  /// oldest. Per-card, session-only — not persisted.
  static const int _tapeCap = 50;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  MathValue? _result;
  MathValue? _lastGood;
  MathError? _error;
  bool _showingStale = false;
  AngleUnit _angleUnit = AngleUnit.radians;
  HistoryRecorder? _recorder;

  /// Visible tape of past `expression = result` evaluations, most-recent last.
  /// Canvas-only (shown above [kToolCanvasWide]); ignored at phone width.
  final List<({String expr, String result})> _tape =
      <({String expr, String result})>[];

  @override
  void initState() {
    super.initState();
    _loadAngleUnit();
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
  void didUpdateWidget(MathBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (plain-number canonical) ────────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical is this body's evaluated result as a plain number string —
  /// empty when the expression is incomplete, errored, or unset.
  @override
  String currentCanonical() {
    final MathValue? r = _result;
    return r == null ? '' : _formatPrimary(r);
  }

  @override
  void applyInbound(String canonical) {
    // Re-project a peer's number as a literal expression so [_parse] evaluates
    // it straight back to [canonical].
    _controller.text = canonical;
    _parse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'math',
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
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAngleUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AngleUnit? loaded = _decodeAngleUnit(
      prefs.getString(_angleUnitPrefsKey),
    );
    if (loaded == null || loaded == _angleUnit || !mounted) return;
    setState(() => _angleUnit = loaded);
    if (_controller.text.trim().isNotEmpty) _parse();
  }

  Future<void> _setAngleUnit(AngleUnit next) async {
    if (next == _angleUnit) return;
    setState(() => _angleUnit = next);
    if (_controller.text.trim().isNotEmpty) _parse();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_angleUnitPrefsKey, _encodeAngleUnit(next));
  }

  static String _encodeAngleUnit(AngleUnit u) => switch (u) {
    AngleUnit.radians => 'radians',
    AngleUnit.degrees => 'degrees',
  };

  static AngleUnit? _decodeAngleUnit(String? raw) => switch (raw) {
    'radians' => AngleUnit.radians,
    'degrees' => AngleUnit.degrees,
    _ => null,
  };

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _parse);
  }

  void _parse() {
    final String input = _controller.text;
    if (input.trim().isEmpty) {
      if (_result == null && _error == null && !_showingStale) return;
      setState(() {
        _result = null;
        _error = null;
        _showingStale = false;
      });
      emitToLink();
      return;
    }
    final MathParseResult res = MathParser.parse(
      input,
      ctx: MathContext(angleUnit: _angleUnit, lastAnswer: _lastGood),
    );
    switch (res) {
      case MathOk(:final MathValue value):
        if (!identical(_result, value)) {
          setState(() {
            _result = value;
            _lastGood = value;
            _error = null;
            _showingStale = false;
          });
        }
        _pushTape(input.trim(), _formatPrimary(value));
        _recorder?.record(input, _formatPrimary(value));
        emitToLink();
      case MathIncomplete():
        final bool nextStale = _result != null;
        if (_error == null && _showingStale == nextStale) return;
        setState(() {
          _error = null;
          _showingStale = nextStale;
        });
      case MathErr(:final MathError error):
        if (_error == error && _result == null) return;
        setState(() {
          _error = error;
          _result = null;
          _showingStale = false;
        });
        emitToLink();
    }
  }

  /// Appends a `expr = result` entry to the visible tape, skipping a repeat of
  /// the trailing entry (debounced re-parses of the same input don't stack).
  void _pushTape(String expr, String result) {
    if (expr.isEmpty) return;
    final ({String expr, String result}) entry = (expr: expr, result: result);
    if (_tape.isNotEmpty &&
        _tape.last.expr == entry.expr &&
        _tape.last.result == entry.result) {
      return;
    }
    setState(() {
      _tape.add(entry);
      if (_tape.length > _tapeCap) _tape.removeAt(0);
    });
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
      _showingStale = false;
    });
  }

  void _insertAns() {
    final TextEditingValue v = _controller.value;
    final String before = v.selection.isValid
        ? v.text.substring(0, v.selection.start)
        : v.text;
    final String after = v.selection.isValid
        ? v.text.substring(v.selection.end)
        : '';
    final String joined = '${before}ans$after';
    _controller.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: before.length + 'ans'.length),
    );
    _focusNode.requestFocus();
    _parse();
  }

  @override
  Widget build(BuildContext context) {
    final MathValue? result = _result;
    final MathError? error = _error;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kToolCanvasWide;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ..._buildCore(result, error),
            // Canvas-only: a scrollable tape of this card's past evaluations.
            // Below [kToolCanvasWide] (every phone) the body is unchanged.
            if (wide && _tape.isNotEmpty) ...<Widget>[
              const SizedBox(height: MqSpacing.lg),
              _buildTape(),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _buildCore(MathValue? result, MathError? error) {
    return <Widget>[
      MqInput(
        controller: _controller,
        focusNode: _focusNode,
        label: 'Expression',
        placeholder: '2*(3+4) - sin(pi/2)',
        onChanged: _onChanged,
        onPaste: (_) => _recorder?.markPaste(),
      ),
      const SizedBox(height: MqSpacing.md),
      MqSegmented<AngleUnit>(
        options: const <AngleUnit, String>{
          AngleUnit.radians: 'Radians',
          AngleUnit.degrees: 'Degrees',
        },
        selected: _angleUnit,
        onChanged: _setAngleUnit,
      ),
      if (_lastGood != null) ...<Widget>[
        const SizedBox(height: MqSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: MqChip(
            label: 'ans = ${_formatPrimary(_lastGood!)}',
            icon: MqIcons.history,
            accent: false,
            mono: true,
            onTap: _insertAns,
          ),
        ),
      ],
      const SizedBox(height: MqSpacing.lg),
      if (error != null)
        MqMonoCell(label: 'Error', value: error.message, copyable: false)
      else if (result != null)
        Opacity(
          opacity: _showingStale ? 0.5 : 1.0,
          child: _buildResults(result),
        )
      else
        const MqEmptyHint(
          label: 'Type an expression — `pi`, `sin`, `ans` all work.',
        ),
    ];
  }

  Widget _buildResults(MathValue v) {
    final String primary = _formatPrimary(v);
    final String? scientific = _formatScientific(v);
    final ({String hex, String bin})? integerForms = _formatIntegerForms(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSectionHeader(
          label: 'Result',
          trailing: v.isApproximate
              ? const MqStatus(
                  label: '≈ approximate',
                  kind: MqStatusKind.warning,
                )
              : null,
        ),
        MqMonoCell(
          label: 'Value',
          value: primary,
          accent: true,
          large: true,
          // Canvas-only: the result is the number canonical, draggable to a
          // Number Base or Timestamp card. Inert on mobile (no PipeScope).
          pipeType: ContentType.number,
        ),
        if (scientific != null) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Scientific', value: scientific),
        ],
        if (integerForms != null) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Hex', value: integerForms.hex),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Binary', value: integerForms.bin),
        ],
        OpenInFooter(
          output: primary,
          excludeUtilityId: 'math',
          onSwitchTool: widget.onSwitchTool,
        ),
      ],
    );
  }

  // TODO(phase7): ↑/↓ tape recall — fiddly to test, deferred per plan.
  Widget _buildTape() {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MqSectionHeader(label: 'Tape'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.monoBg,
              borderRadius: BorderRadius.circular(MqRadius.sm),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              reverse: true,
              padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.md,
                vertical: MqSpacing.sm,
              ),
              itemCount: _tape.length,
              separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.xs),
              itemBuilder: (BuildContext context, int i) {
                // reverse:true counts from the newest; map to most-recent first.
                final ({String expr, String result}) e =
                    _tape[_tape.length - 1 - i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        e.expr,
                        style: MqTextStyles.monoSm.copyWith(color: c.textSec),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MqSpacing.sm,
                      ),
                      child: Text(
                        '=',
                        style: MqTextStyles.monoSm.copyWith(color: c.textTer),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        e.result,
                        textAlign: TextAlign.right,
                        style: MqTextStyles.monoSm.copyWith(color: c.monoText),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Strip trailing zeros (and an orphan dot) before the exponent so
  // `1.000000e+3` renders as `1e+3` rather than `1.e+3`.
  static final RegExp _trailingZeroExponent = RegExp(r'\.?0+e');

  String _formatPrimary(MathValue v) {
    final Rational? r = v.exact;
    if (!v.isApproximate && r != null && r.hasFinitePrecision) {
      return _trimTrailingZeros(r.toDecimal().toString());
    }
    return _trimTrailingZeros(v.approx.toString());
  }

  String? _formatScientific(MathValue v) {
    final double d = v.approx.toDouble();
    if (d == 0) return null;
    final double absD = d.abs();
    if (absD >= 1e7 || absD < 1e-4) {
      return d.toStringAsExponential(6).replaceAll(_trailingZeroExponent, 'e');
    }
    return null;
  }

  ({String hex, String bin})? _formatIntegerForms(MathValue v) {
    if (v.isApproximate || v.exact == null) return null;
    final Rational r = v.exact!;
    if (!r.isInteger) return null;
    final BigInt big = r.truncate();
    // int64 range — keeps hex/binary readable; larger ints would dominate
    // the result panel.
    if (big.bitLength > 63) return null;
    final int n = big.toInt();
    final String hex = n < 0
        ? '-0x${(-n).toRadixString(16).toUpperCase()}'
        : '0x${n.toRadixString(16).toUpperCase()}';
    final String bin = n < 0
        ? '-0b${(-n).toRadixString(2)}'
        : '0b${n.toRadixString(2)}';
    return (hex: hex, bin: bin);
  }

  static String _trimTrailingZeros(String s) {
    if (!s.contains('.')) return s;
    String out = s;
    while (out.endsWith('0')) {
      out = out.substring(0, out.length - 1);
    }
    if (out.endsWith('.')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}
