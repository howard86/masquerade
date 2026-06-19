import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/generator.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

/// Generates passwords, random tokens, and UUIDs. Has no input shape, so it is
/// reached from the Home grid / search only (`detect` returns false). Generated
/// values are never written to history — only a non-secret config descriptor.
class GeneratorBody extends StatefulWidget {
  const GeneratorBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  // initialInput / link accepted for builder-signature parity; a generator has
  // no input to seed and is not linkable, so both are ignored.
  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;
  final LinkChannel? link;

  @override
  State<GeneratorBody> createState() => _GeneratorBodyState();
}

class _GeneratorBodyState extends State<GeneratorBody> {
  final TextEditingController _lengthCtrl = TextEditingController(text: '20');
  final TextEditingController _bytesCtrl = TextEditingController(text: '16');

  GenMode _mode = GenMode.password;
  bool _lower = true;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  TokenFormat _tokenFormat = TokenFormat.hex;
  GenUuidVersion _uuidVersion = GenUuidVersion.v4;

  String _output = '';
  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
    _output = _build();
  }

  @override
  void didUpdateWidget(GeneratorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) _updateActionBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'generator',
      );
      // Log the opening config (debounced + deduped by the recorder).
      _record();
    }
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _lengthCtrl.dispose();
    _bytesCtrl.dispose();
    super.dispose();
  }

  void _updateActionBar() {
    widget.actionBar?.bind(onClear: _reset);
  }

  int get _length => (int.tryParse(_lengthCtrl.text) ?? 20).clamp(
    Generator.minLength,
    Generator.maxLength,
  );

  int get _bytes => (int.tryParse(_bytesCtrl.text) ?? 16).clamp(
    Generator.minBytes,
    Generator.maxBytes,
  );

  String _build() => switch (_mode) {
    GenMode.password => Generator.password(
      length: _length,
      lower: _lower,
      upper: _upper,
      digits: _digits,
      symbols: _symbols,
    ),
    GenMode.token => Generator.token(byteCount: _bytes, format: _tokenFormat),
    GenMode.uuid => Generator.uuid(_uuidVersion),
  };

  /// Re-derive [_output] and log the (non-secret) config. Called on every
  /// option change and on the Regenerate button.
  void _generate() {
    setState(() => _output = _build());
    _record();
  }

  void _record() {
    if (_output.isEmpty) return;
    // The config descriptor is recorded — never the generated secret.
    _recorder?.record(_configDescriptor(), '');
  }

  String _configDescriptor() => switch (_mode) {
    GenMode.password => 'password · $_length · ${_classLabel()}',
    GenMode.token => 'token · ${_bytes}B · ${_tokenFormatLabel(_tokenFormat)}',
    GenMode.uuid => 'uuid · ${_uuidVersion == GenUuidVersion.v4 ? 'v4' : 'v7'}',
  };

  String _classLabel() {
    final List<String> parts = <String>[
      if (_lower) 'a-z',
      if (_upper) 'A-Z',
      if (_digits) '0-9',
      if (_symbols) 'sym',
    ];
    return parts.isEmpty ? 'none' : parts.join(' ');
  }

  /// Size of the merged character pool for the enabled password classes.
  int get _poolSize =>
      (_lower ? Generator.lowerChars.length : 0) +
      (_upper ? Generator.upperChars.length : 0) +
      (_digits ? Generator.digitChars.length : 0) +
      (_symbols ? Generator.symbolChars.length : 0);

  /// One-line strength readout shown under a generated password, e.g.
  /// "≈ 119 bits · strong".
  String _entropyHint() {
    final double bits = Generator.entropyBits(_length, _poolSize);
    final String label = bits < 40
        ? 'weak'
        : bits < 80
        ? 'fair'
        : 'strong';
    return '≈ ${bits.round()} bits · $label';
  }

  void _reset() {
    setState(() {
      _mode = GenMode.password;
      _lengthCtrl.text = '20';
      _bytesCtrl.text = '16';
      _lower = true;
      _upper = true;
      _digits = true;
      _symbols = true;
      _tokenFormat = TokenFormat.hex;
      _uuidVersion = GenUuidVersion.v4;
      _output = _build();
    });
    _record();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<GenMode>(
          options: const <GenMode, String>{
            GenMode.password: 'Password',
            GenMode.token: 'Token',
            GenMode.uuid: 'UUID',
          },
          selected: _mode,
          onChanged: (GenMode m) {
            setState(() => _mode = m);
            _generate();
          },
        ),
        const SizedBox(height: MqSpacing.lg),
        ..._buildOptions(),
        const SizedBox(height: MqSpacing.lg),
        if (_output.isEmpty)
          const MqEmptyHint(label: 'Enable at least one character set.')
        else
          MqMonoCell(
            label: _outputLabel(),
            value: _output,
            hint: _mode == GenMode.password ? _entropyHint() : null,
          ),
        const SizedBox(height: MqSpacing.md),
        MqButton(
          label: 'Regenerate',
          icon: MqIcons.dices,
          full: true,
          onPressed: _generate,
        ),
        if (_output.isNotEmpty)
          OpenInFooter(
            output: _output,
            excludeUtilityId: 'generator',
            onSwitchTool: widget.onSwitchTool,
          ),
      ],
    );
  }

  List<Widget> _buildOptions() => switch (_mode) {
    GenMode.password => <Widget>[
      MqInput(
        controller: _lengthCtrl,
        label: 'Length',
        placeholder: '20',
        keyboardType: TextInputType.number,
        onChanged: (_) => _generate(),
      ),
      const SizedBox(height: MqSpacing.md),
      const MqSectionHeader(label: 'Character sets'),
      const SizedBox(height: MqSpacing.sm),
      Wrap(
        spacing: MqSpacing.sm,
        runSpacing: MqSpacing.sm,
        children: <Widget>[
          _classChip('a-z', _lower, () => _lower = !_lower),
          _classChip('A-Z', _upper, () => _upper = !_upper),
          _classChip('0-9', _digits, () => _digits = !_digits),
          _classChip('!@#', _symbols, () => _symbols = !_symbols),
        ],
      ),
    ],
    GenMode.token => <Widget>[
      MqInput(
        controller: _bytesCtrl,
        label: 'Bytes',
        placeholder: '16',
        keyboardType: TextInputType.number,
        onChanged: (_) => _generate(),
      ),
      const SizedBox(height: MqSpacing.md),
      MqSegmented<TokenFormat>(
        options: const <TokenFormat, String>{
          TokenFormat.hex: 'Hex',
          TokenFormat.base64url: 'Base64url',
          TokenFormat.alphanumeric: 'Alnum',
        },
        selected: _tokenFormat,
        onChanged: (TokenFormat f) {
          setState(() => _tokenFormat = f);
          _generate();
        },
      ),
    ],
    GenMode.uuid => <Widget>[
      MqSegmented<GenUuidVersion>(
        options: const <GenUuidVersion, String>{
          GenUuidVersion.v4: 'v4 (random)',
          GenUuidVersion.v7: 'v7 (time)',
        },
        selected: _uuidVersion,
        onChanged: (GenUuidVersion v) {
          setState(() => _uuidVersion = v);
          _generate();
        },
      ),
    ],
  };

  Widget _classChip(String label, bool on, VoidCallback toggle) => MqChip(
    label: label,
    selected: on,
    mono: false,
    onTap: () {
      toggle();
      _generate();
    },
  );

  String _outputLabel() => switch (_mode) {
    GenMode.password => 'Password',
    GenMode.token => 'Token',
    GenMode.uuid => _uuidVersion == GenUuidVersion.v4 ? 'UUID v4' : 'UUID v7',
  };

  String _tokenFormatLabel(TokenFormat f) => switch (f) {
    TokenFormat.hex => 'hex',
    TokenFormat.base64url => 'base64url',
    TokenFormat.alphanumeric => 'alnum',
  };
}
