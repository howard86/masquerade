import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/json_parser.dart';
import '../../utils/toml_parser.dart';
import '../../utils/yaml_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_dropdown.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

enum SourceFormat {
  auto('Auto', ''),
  json('JSON', 'JSON'),
  yaml('YAML', 'YAML'),
  toml('TOML', 'TOML');

  const SourceFormat(this.dropdownLabel, this.displayName);

  /// Label shown in the From dropdown.
  final String dropdownLabel;

  /// Format name shown in the "Detected …" chip. Empty for [auto] since
  /// auto is never the *detected* format.
  final String displayName;
}

enum TargetFormat {
  prettyJson('Pretty JSON', 'PRETTY'),
  minifiedJson('Minified JSON', 'MINIFY'),
  tree('Tree', 'TREE'),
  yaml('YAML', 'YAML'),
  toml('TOML', 'TOML');

  const TargetFormat(this.dropdownLabel, this.cellLabel);

  /// Label shown in the To dropdown.
  final String dropdownLabel;

  /// Uppercase label shown on the [MqMonoCell] output.
  final String cellLabel;
}

/// Body returned for a successful parse; the body is dispatched to the right
/// emitter by [TargetFormat] and may carry a `Multi-doc · 1 of N` chip when
/// the source was a multi-doc YAML stream.
class _Parsed {
  const _Parsed({
    required this.value,
    required this.detectedFormat,
    this.docCount = 1,
  });

  final Object? value;
  final SourceFormat detectedFormat; // never `auto`
  final int docCount;
}

class _ParseError {
  const _ParseError({
    required this.message,
    this.line,
    this.column,
    this.fixable = false,
    this.fixedText,
  });
  final String message;
  final int? line;
  final int? column;

  /// JSON-only: when true, [fixedText] is the edited input that re-parses
  /// cleanly and the body offers a one-tap fix. YAML/TOML never set these.
  final bool fixable;
  final String? fixedText;
}

class JSONBody extends StatefulWidget {
  const JSONBody({
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

  /// Non-null when this card is in a canvas Link group. JSON is the group's
  /// identity peer: its input text *is* the canonical value (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<JSONBody> createState() => _JSONBodyState();
}

class _JSONBodyState extends State<JSONBody> with LinkableToolBody<JSONBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  SourceFormat _source = SourceFormat.auto;
  TargetFormat _target = TargetFormat.prettyJson;
  _Parsed? _parsed;
  _ParseError? _error;
  String? _output;
  String? _footerMinified;
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
  void didUpdateWidget(JSONBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (identity peer) ─────────────────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  @override
  String currentCanonical() => _controller.text;

  @override
  void applyInbound(String canonical) {
    _controller.text = canonical;
    _parse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'json',
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
        _parsed = null;
        _error = null;
        _output = null;
        _footerMinified = null;
      });
      emitToLink();
      return;
    }
    final ({_Parsed? parsed, _ParseError? error}) r = _runParse(input, _source);
    final _Parsed? parsed = r.parsed;
    final String? minified = parsed == null
        ? null
        : JSONParser.minify(parsed.value);
    setState(() {
      _parsed = parsed;
      _error = r.error;
      _footerMinified = minified;
      // TOML can't represent a non-table root; drop back to Pretty JSON so the
      // now-hidden TOML target can't leave a stale, unrenderable selection.
      if (!_tomlAllowed && _target == TargetFormat.toml) {
        _target = TargetFormat.prettyJson;
      }
      _output = parsed == null ? null : _renderOutput(parsed.value, _target);
    });
    if (parsed != null) _recorder?.record(input, minified!);
    emitToLink();
  }

  /// Computes the output string for [target]. The TOML target is hidden by
  /// `_FromToRow` whenever the current value isn't a `Map`, and `_parse`
  /// resets the selection off TOML in that case, so `target` is always
  /// renderable here. Called from `_parse()` and the Target dropdown handler.
  String _renderOutput(Object? value, TargetFormat target) {
    switch (target) {
      case TargetFormat.prettyJson:
        return JSONParser.pretty(value);
      case TargetFormat.minifiedJson:
        return JSONParser.minify(value);
      case TargetFormat.tree:
        return JSONParser.tree(value);
      case TargetFormat.yaml:
        return YamlParser.emit(value);
      case TargetFormat.toml:
        return TomlParser.emit(value);
    }
  }

  ({_Parsed? parsed, _ParseError? error}) _runParse(
    String input,
    SourceFormat source,
  ) {
    switch (source) {
      case SourceFormat.json:
        return _tryJson(input);
      case SourceFormat.yaml:
        return _tryYaml(input);
      case SourceFormat.toml:
        return _tryToml(input);
      case SourceFormat.auto:
        // `{...}` is JSON only. `[name]\n...` is a TOML table header — must
        // be matched before JSON-array since both start with `[`. YAML last
        // because its `key: value` grammar would otherwise swallow
        // malformed JSON/TOML.
        final String trimmed = input.trim();
        if (trimmed.startsWith('{')) return _tryJson(input);
        if (TomlParser.looksLike(trimmed)) return _tryToml(input);
        if (trimmed.startsWith('[')) return _tryJson(input);
        return _tryYaml(input);
    }
  }

  ({_Parsed? parsed, _ParseError? error}) _tryJson(String input) {
    final JSONParseResult r = JSONParser.parse(input);
    if (r is JSONOk) {
      return (
        parsed: _Parsed(
          value: r.value.value,
          detectedFormat: SourceFormat.json,
        ),
        error: null,
      );
    }
    final JSONErr err = r as JSONErr;
    return (
      parsed: null,
      error: _ParseError(
        message: err.error.message,
        line: err.error.line,
        column: err.error.column,
        fixable: err.error.fixable,
        fixedText: err.error.fixedText,
      ),
    );
  }

  ({_Parsed? parsed, _ParseError? error}) _tryYaml(String input) {
    final YamlParseResult r = YamlParser.parse(input);
    if (r is YamlOk) {
      return (
        parsed: _Parsed(
          value: r.value,
          detectedFormat: SourceFormat.yaml,
          docCount: r.docCount,
        ),
        error: null,
      );
    }
    final YamlErr err = r as YamlErr;
    return (
      parsed: null,
      error: _ParseError(
        message: err.message,
        line: err.line,
        column: err.column,
      ),
    );
  }

  ({_Parsed? parsed, _ParseError? error}) _tryToml(String input) {
    final TomlParseResult r = TomlParser.parse(input);
    if (r is TomlOk) {
      return (
        parsed: _Parsed(value: r.value, detectedFormat: SourceFormat.toml),
        error: null,
      );
    }
    final TomlErr err = r as TomlErr;
    return (
      parsed: null,
      error: _ParseError(
        message: err.message,
        line: err.line,
        column: err.column,
      ),
    );
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
      _parsed = null;
      _error = null;
      _output = null;
      _footerMinified = null;
    });
  }

  void _applyAutoFix() {
    final _ParseError? err = _error;
    if (err == null || !err.fixable || err.fixedText == null) return;
    HapticFeedback.selectionClick();
    _controller.text = err.fixedText!;
    _parse();
  }

  void _setTarget(TargetFormat t) {
    setState(() {
      _target = t;
      _output = _parsed == null ? null : _renderOutput(_parsed!.value, t);
    });
  }

  void _swap() {
    final _Parsed? parsed = _parsed;
    final String? output = _output;
    if (parsed == null || output == null || !_swapEnabled) return;
    final SourceFormat nextSource = _targetToSource(_target);
    final TargetFormat nextTarget = _sourceToTarget(parsed.detectedFormat);
    _controller.text = output;
    setState(() {
      _source = nextSource;
      _target = nextTarget;
    });
    _parse();
  }

  bool get _swapEnabled =>
      _parsed != null && _output != null && _target != TargetFormat.tree;

  /// TOML can only represent a table (`Map`) at the root. Drives both the
  /// reset in `_parse` and the To-dropdown filtering in `_FromToRow`. True
  /// when nothing is parsed yet, so the option isn't hidden before input.
  bool get _tomlAllowed => _parsed == null || _parsed!.value is Map;

  static SourceFormat _targetToSource(TargetFormat t) {
    switch (t) {
      case TargetFormat.prettyJson:
      case TargetFormat.minifiedJson:
        return SourceFormat.json;
      case TargetFormat.yaml:
        return SourceFormat.yaml;
      case TargetFormat.toml:
        return SourceFormat.toml;
      case TargetFormat.tree:
        throw StateError('swap should be disabled when target is Tree');
    }
  }

  static TargetFormat _sourceToTarget(SourceFormat s) {
    switch (s) {
      case SourceFormat.json:
      case SourceFormat.auto:
        return TargetFormat.prettyJson;
      case SourceFormat.yaml:
        return TargetFormat.yaml;
      case SourceFormat.toml:
        return TargetFormat.toml;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: '{"hello": "world"}',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
          multiline: true,
          minLines: 4,
          maxLines: 10,
        ),
        if (_parsed != null) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          _DetectionChips(parsed: _parsed!, sourceMode: _source),
        ],
        const SizedBox(height: MqSpacing.md),
        _FromToRow(
          source: _source,
          target: _target,
          tomlAllowed: _tomlAllowed,
          swapEnabled: _swapEnabled,
          onSource: (SourceFormat s) {
            setState(() => _source = s);
            _parse();
          },
          onTarget: _setTarget,
          onSwap: _swap,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null) ...<Widget>[
          MqStatus(label: _errorLabel(_error!), kind: MqStatusKind.danger),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Reason', value: _error!.message, copyable: false),
          if (_error!.fixable) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqButton(
              label: 'Fix automatically',
              icon: MqIcons.check,
              variant: MqButtonVariant.glass,
              onPressed: _applyAutoFix,
              full: true,
            ),
          ],
        ] else if (_output != null) ...<Widget>[
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(label: _target.cellLabel, value: _output!),
          OpenInFooter(
            output: _footerMinified,
            excludeUtilityId: 'json',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(label: 'Paste JSON, YAML, or TOML to convert.'),
      ],
    );
  }

  static String _errorLabel(_ParseError e) {
    final StringBuffer b = StringBuffer('Error');
    if (e.line != null) {
      b.write(' · line ${e.line}');
      if (e.column != null) b.write(' col ${e.column}');
    }
    return b.toString();
  }
}

class _DetectionChips extends StatelessWidget {
  const _DetectionChips({required this.parsed, required this.sourceMode});

  final _Parsed parsed;
  final SourceFormat sourceMode;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[];
    if (sourceMode == SourceFormat.auto) {
      chips.add(MqChip(label: 'Detected ${parsed.detectedFormat.displayName}'));
    }
    if (parsed.docCount > 1) {
      chips.add(MqChip(label: 'Multi-doc · 1 of ${parsed.docCount}'));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: MqSpacing.sm,
      runSpacing: MqSpacing.xs,
      children: chips,
    );
  }
}

class _FromToRow extends StatelessWidget {
  const _FromToRow({
    required this.source,
    required this.target,
    required this.tomlAllowed,
    required this.swapEnabled,
    required this.onSource,
    required this.onTarget,
    required this.onSwap,
  });

  final SourceFormat source;
  final TargetFormat target;
  final bool tomlAllowed;
  final bool swapEnabled;
  final ValueChanged<SourceFormat> onSource;
  final ValueChanged<TargetFormat> onTarget;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: MqDropdown<SourceFormat>(
            label: 'From',
            selected: source,
            options: <SourceFormat, String>{
              for (final SourceFormat f in SourceFormat.values)
                f: f.dropdownLabel,
            },
            onChanged: onSource,
          ),
        ),
        const SizedBox(width: MqSpacing.sm),
        Semantics(
          button: true,
          enabled: swapEnabled,
          label: 'Swap source and target',
          child: CupertinoButton(
            padding: const EdgeInsets.all(MqSpacing.sm),
            minimumSize: const Size(40, 40),
            borderRadius: BorderRadius.circular(MqRadius.sm),
            onPressed: swapEnabled ? onSwap : null,
            child: Icon(
              MqIcons.swap,
              size: 18,
              color: swapEnabled ? c.accent : c.textTer,
            ),
          ),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: MqDropdown<TargetFormat>(
            label: 'To',
            selected: target,
            options: <TargetFormat, String>{
              for (final TargetFormat f in TargetFormat.values)
                if (f != TargetFormat.toml || tomlAllowed) f: f.dropdownLabel,
            },
            onChanged: onTarget,
          ),
        ),
      ],
    );
  }
}
