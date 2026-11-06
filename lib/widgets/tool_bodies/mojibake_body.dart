import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/mojibake_parser.dart';
import '../../utils/sensitive_data_policy.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class MojibakeBody extends StatefulWidget implements ToolBodyWidget {
  const MojibakeBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  @override
  final String? initialInput;
  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;

  @override
  State<MojibakeBody> createState() => _MojibakeBodyState();
}

class _MojibakeBodyState extends State<MojibakeBody>
    with ToolBodyScaffold<MojibakeBody> {
  /// Null means Auto.
  MojibakeCodec? _codec;
  MojibakeOk? _result;
  String? _error;
  bool _sensitive = false;

  @override
  String get utilityId => 'mojibake';

  // Whitespace and non-ASCII are the whole point of this tool, so only a
  // truly empty field is "nothing to do".
  @override
  bool isBlank(String input) => input.isEmpty;

  @override
  void parse(String input) {
    final MojibakeResult r = MojibakeParser.parse(input, codec: _codec);
    switch (r) {
      case MojibakeErr(:final message):
        setState(() {
          _result = null;
          _error = message;
          _sensitive = false;
        });
      case MojibakeOk ok:
        setState(() {
          _result = ok;
          _error = null;
          _sensitive =
              SensitiveDataPolicy.containsSensitiveArtifact(input) ||
              SensitiveDataPolicy.containsSensitiveArtifact(ok.text);
        });
        recordOutput(input, ok.text);
    }
  }

  @override
  void reset() {
    setState(() {
      _result = null;
      _error = null;
      _sensitive = false;
    });
  }

  void _setCodec(MojibakeCodec? codec) {
    setState(() => _codec = codec);
    reparse();
  }

  @override
  Widget build(BuildContext context) {
    final MojibakeOk? ok = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Garbled text',
          placeholder: 'â€™ Ã© ‚îå‚îÄ…',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            MqChip(
              label: 'Auto',
              selected: _codec == null,
              mono: false,
              onTap: () => _setCodec(null),
            ),
            for (final MojibakeCodec c in MojibakeCodec.values)
              MqChip(
                label: c.label,
                selected: _codec == c,
                mono: false,
                onTap: () => _setCodec(c),
              ),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: MqStatus(label: _error!, kind: MqStatusKind.danger),
          )
        else if (ok == null)
          const MqEmptyHint(label: 'Paste garbled text to repair it.')
        else ...<Widget>[
          const MqSectionHeader(label: 'Repaired'),
          MqMonoCell(
            label: 'Text',
            value: ok.text,
            accent: true,
            sensitive: _sensitive,
          ),
          const SizedBox(height: MqSpacing.sm),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              MqChip(label: 'Codec: ${ok.codec.label}', mono: false),
              MqChip(label: 'Fixed: ${ok.fixedSequences}', mono: false),
              MqChip(label: 'Passes: ${ok.passes}', mono: false),
            ],
          ),
          OpenInFooter(
            output: ok.text,
            excludeUtilityId: 'mojibake',
            onSwitchTool: widget.onSwitchTool,
            protectedSource: _sensitive,
          ),
        ],
      ],
    );
  }
}
