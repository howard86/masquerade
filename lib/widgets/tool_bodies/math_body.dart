import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rational/rational.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
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
import 'open_in_footer.dart';
import 'seed_source.dart';

class MathBody extends StatefulWidget {
  const MathBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  @override
  State<MathBody> createState() => _MathBodyState();
}

class _MathBodyState extends State<MathBody> {
  static const String _angleUnitPrefsKey = 'mq.math.angle_unit';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  MathValue? _result;
  MathValue? _lastGood;
  MathError? _error;
  bool _showingStale = false;
  AngleUnit _angleUnit = AngleUnit.radians;
  HistoryRecorder? _recorder;

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
        _recorder?.record(input, _formatPrimary(value));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
      ],
    );
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
        MqMonoCell(label: 'Value', value: primary, accent: true, large: true),
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
