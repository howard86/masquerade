import 'package:flutter/cupertino.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../utils/markdown_parser.dart';
import '../../utils/sensitive_data_policy.dart';
import '../mq/md_renderer.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class MarkdownBody extends StatefulWidget implements ToolBodyWidget {
  const MarkdownBody({
    super.key,
    this.initialInput,
    this.initialArtifact,
    this.seedSource = SeedSource.none,
    this.actionBar,
  });

  @override
  final String? initialInput;
  final Artifact<Object?>? initialArtifact;
  @override
  final SeedSource seedSource;
  @override
  final ToolActionBarController? actionBar;

  @override
  State<MarkdownBody> createState() => _MarkdownBodyState();
}

class _MarkdownBodyState extends State<MarkdownBody>
    with ToolBodyScaffold<MarkdownBody> {
  MarkdownOk? _document;
  String? _error;

  @override
  String get utilityId => 'markdown';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void parse(String input) {
    final MarkdownParseResult result = MarkdownParser.parse(input);
    setState(() {
      _document = result is MarkdownOk ? result : null;
      _error = result is MarkdownErr ? result.message : null;
    });
    if (result is MarkdownOk &&
        widget.initialArtifact?.isSensitive != true &&
        !SensitiveDataPolicy.protects(
          utilityId: 'markdown',
          values: <String>[input],
        ) &&
        !SensitiveDataPolicy.containsSecretLikeValue(input)) {
      recordOutput(input, input);
    }
  }

  @override
  void reset() => setState(() {
    _document = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final MarkdownOk? document = _document;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Markdown',
          placeholder: '# Heading\n\nWrite **Markdown** here…',
          multiline: true,
          minLines: 8,
          maxLines: 16,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          error: _error,
          semanticsLabel: 'Markdown source',
        ),
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Preview'),
        if (document == null || document.blocks.isEmpty)
          const MqEmptyHint(label: 'Enter Markdown to preview it.')
        else ...<Widget>[
          if (document.headings.isNotEmpty) ...<Widget>[
            MqStatus(
              label:
                  '${document.headings.length} heading${document.headings.length == 1 ? '' : 's'}',
              kind: MqStatusKind.info,
            ),
            const SizedBox(height: MqSpacing.md),
          ],
          MqMarkdownRenderer(blocks: document.blocks),
        ],
      ],
    );
  }
}
