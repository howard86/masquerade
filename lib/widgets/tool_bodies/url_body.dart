import 'package:flutter/cupertino.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
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

  /// The live re-encoded query string for the (possibly edited) [_pairs], kept
  /// in sync via [UrlParser.buildQuery]. Null until a parse yields pairs.
  String? _query;
  String? _error;

  /// Bumped on every fresh parse so the editable query table re-keys (and
  /// rebuilds its row controllers from the new pairs); in-place edits leave it
  /// untouched so the user's cursor and controllers survive an edit.
  int _parseSeq = 0;

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
          _query = pairs.isEmpty ? null : UrlParser.buildQuery(pairs);
          _error = null;
          _parseSeq++;
        });
        recordOutput(input, output);
        emitToLink();
      case UrlError(:final message):
        setState(() {
          _output = null;
          _pairs = const <QueryPair>[];
          _query = null;
          _error = message;
        });
    }
  }

  @override
  void reset() {
    setState(() {
      _output = null;
      _pairs = const <QueryPair>[];
      _query = null;
      _error = null;
    });
    emitToLink();
  }

  /// Applies an in-place edit to a query pair from the editable table, then
  /// re-encodes the whole query via [UrlParser.buildQuery] so the displayed
  /// query string updates live and round-trips. Edits are UI-only — they do not
  /// touch the input controller or history.
  void _onPairEdited(List<QueryPair> pairs) {
    setState(() {
      _pairs = pairs;
      _query = UrlParser.buildQuery(pairs);
    });
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
            _QueryEditor(
              // Re-key per parse so a fresh parse rebuilds the row controllers;
              // an in-place edit keeps the same key (and the user's cursor).
              key: ValueKey<int>(_parseSeq),
              pairs: _pairs,
              onChanged: _onPairEdited,
            ),
            if (_query != null) ...<Widget>[
              const SizedBox(height: MqSpacing.md),
              MqMonoCell(label: 'Rebuilt query', value: _query!, accent: true),
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

/// Editable two-way table of the parsed query [pairs]. Each pair gets a key and
/// a value field; editing either rebuilds the [QueryPair] list and calls
/// [onChanged] so the parent re-encodes the query via [UrlParser.buildQuery].
///
/// Owns its row controllers (the editing source of truth) and seeds them once
/// from [pairs]. The parent re-keys this widget per parse, so a fresh parse
/// constructs a new state with controllers reseeded from the new pairs while an
/// in-place edit preserves the user's cursor.
class _QueryEditor extends StatefulWidget {
  const _QueryEditor({super.key, required this.pairs, required this.onChanged});

  final List<QueryPair> pairs;
  final ValueChanged<List<QueryPair>> onChanged;

  @override
  State<_QueryEditor> createState() => _QueryEditorState();
}

class _QueryEditorState extends State<_QueryEditor> {
  late final List<TextEditingController> _keys;
  late final List<TextEditingController> _values;

  @override
  void initState() {
    super.initState();
    _keys = <TextEditingController>[
      for (final QueryPair p in widget.pairs)
        TextEditingController(text: p.key),
    ];
    _values = <TextEditingController>[
      for (final QueryPair p in widget.pairs)
        TextEditingController(text: p.value),
    ];
  }

  @override
  void dispose() {
    for (final TextEditingController c in _keys) {
      c.dispose();
    }
    for (final TextEditingController c in _values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(<QueryPair>[
      for (int i = 0; i < _keys.length; i++)
        QueryPair(_keys[i].text, _values[i].text),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < widget.pairs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: MqSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.monoBg,
              borderRadius: BorderRadius.circular(MqRadius.sm),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.md,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MqInput(
                    controller: _keys[i],
                    label: 'Key',
                    placeholder: '(empty key)',
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  MqInput(
                    controller: _values[i],
                    label: 'Value',
                    placeholder: '(empty value)',
                    onChanged: (_) => _emit(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
