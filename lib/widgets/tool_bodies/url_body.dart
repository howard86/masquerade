import 'package:flutter/cupertino.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/url_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class UrlBody extends StatefulWidget implements ToolBodyWidget {
  const UrlBody({
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
  /// value is the plain (decoded) text; this body projects it to the percent-
  /// encoded form in Encode mode and parses encoded edits back (see ADR 0001).
  final LinkChannel? link;

  @override
  State<UrlBody> createState() => _UrlBodyState();
}

class _UrlBodyState extends State<UrlBody>
    with ToolBodyScaffold<UrlBody>, LinkableToolBody<UrlBody> {
  UrlMode _mode = UrlMode.encode;
  String? _output;
  List<QueryPair> _pairs = const <QueryPair>[];
  String? _error;

  @override
  String get utilityId => 'url';

  // Encoding whitespace is meaningful, so only a truly empty field is blank.
  @override
  bool isBlank(String input) => input.isEmpty;

  @override
  void onSeed(String seed) {
    // The hero detector only suggests URL for encoded-looking input, so a seed
    // always enters Decode mode.
    _mode = UrlMode.decode;
  }

  @override
  Widget? actionBarCenter() => MqButton(
    label: 'Swap',
    icon: MqIcons.swap,
    variant: MqButtonVariant.glass,
    onPressed: _output == null ? null : _swap,
    full: true,
  );

  // ─── Canonical-hub link (plain-text canonical) ──────────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical (plain text) is the input in Encode mode and the decoded
  /// output in Decode mode.
  @override
  String currentCanonical() =>
      _mode == UrlMode.encode ? controller.text : (_output ?? '');

  @override
  void applyInbound(String canonical) {
    setInput(
      _mode == UrlMode.encode ? canonical : Uri.encodeComponent(canonical),
      asPaste: false,
    );
  }

  @override
  void parse(String input) {
    switch (UrlParser.parse(input, mode: _mode)) {
      case UrlOk(:final output, :final pairs):
        setState(() {
          _output = output;
          _pairs = pairs;
          _error = null;
        });
        recordOutput(input, output);
        emitToLink();
      case UrlError(:final message):
        setState(() {
          _output = null;
          _pairs = const <QueryPair>[];
          _error = message;
        });
    }
  }

  @override
  void reset() {
    setState(() {
      _output = null;
      _pairs = const <QueryPair>[];
      _error = null;
    });
    emitToLink();
  }

  void _swap() {
    final String? out = _output;
    if (out == null) return;
    setState(() {
      _mode = _mode == UrlMode.encode ? UrlMode.decode : UrlMode.encode;
    });
    setInput(out, asPaste: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<UrlMode>(
          options: const <UrlMode, String>{
            UrlMode.encode: 'Encode',
            UrlMode.decode: 'Decode',
          },
          selected: _mode,
          onChanged: (UrlMode m) {
            setState(() => _mode = m);
            reparse();
          },
        ),
        const SizedBox(height: MqSpacing.md),
        MqInput(
          controller: controller,
          label: 'Input',
          placeholder: _mode == UrlMode.encode
              ? 'Plain text or URL'
              : 'Percent-encoded text',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null)
          MqMonoCell(label: 'Error', value: _error!, copyable: false)
        else if (_output != null) ...<Widget>[
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: _mode == UrlMode.encode ? 'Encoded' : 'Decoded',
            value: _output!,
            accent: true,
            pipeType: _mode == UrlMode.decode ? ContentType.text : null,
          ),
          if (_pairs.isNotEmpty) ...<Widget>[
            const SizedBox(height: MqSpacing.lg),
            const MqSectionHeader(label: 'Query'),
            for (int i = 0; i < _pairs.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: MqSpacing.sm),
              MqMonoCell(
                label: _pairs[i].key.isEmpty ? '(empty key)' : _pairs[i].key,
                value: _pairs[i].value,
              ),
            ],
          ],
          OpenInFooter(
            output: _output,
            excludeUtilityId: 'url',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          MqEmptyHint(
            label: _mode == UrlMode.encode
                ? 'Type text to percent-encode.'
                : 'Paste a percent-encoded string to decode.',
          ),
      ],
    );
  }
}
