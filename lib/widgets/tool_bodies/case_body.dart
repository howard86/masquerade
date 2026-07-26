import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/case_parser.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class CaseBody extends StatefulWidget implements ToolBodyWidget {
  const CaseBody({
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
  State<CaseBody> createState() => _CaseBodyState();
}

class _CaseBodyState extends State<CaseBody> with ToolBodyScaffold<CaseBody> {
  CaseConversions? _result;
  String? _error;

  @override
  String get utilityId => 'case';

  @override
  void parse(String input) {
    final CaseConversions? result = CaseParser.parse(input);
    setState(() {
      _result = result;
      _error = result == null
          ? input.length > CaseParser.maxInputLength
                ? 'Input is limited to ${CaseParser.maxInputLength} characters.'
                : 'Use letters, numbers, spaces, or identifier separators.'
          : null;
    });
    if (result != null) recordOutput(input, result.camelCase);
  }

  @override
  void reset() => setState(() {
    _result = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final CaseConversions? result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Input',
          placeholder: 'XMLHttpRequest · user_id_42',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          error: _error,
        ),
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Detected tokens'),
        MqMonoCell(
          label: 'Tokens',
          value: result?.tokens.join(' · ') ?? '—',
          copyable: false,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (result == null)
          const MqEmptyHint(label: 'Enter an identifier to convert.')
        else ...<Widget>[
          const MqSectionHeader(label: 'Conversions'),
          MqSurface(
            padded: false,
            child: Column(
              children: <Widget>[
                for (final (String, String) row in _rows(result))
                  Padding(
                    padding: const EdgeInsets.all(MqSpacing.xs),
                    child: MqMonoCell(label: row.$1, value: row.$2),
                  ),
              ],
            ),
          ),
          OpenInFooter(
            output: result.camelCase,
            excludeUtilityId: 'case',
            onSwitchTool: widget.onSwitchTool,
          ),
        ],
      ],
    );
  }

  List<(String, String)> _rows(CaseConversions value) => <(String, String)>[
    ('camelCase', value.camelCase),
    ('PascalCase', value.pascalCase),
    ('snake_case', value.snakeCase),
    ('SCREAMING_SNAKE_CASE', value.screamingSnake),
    ('kebab-case', value.kebabCase),
    ('Train-Case', value.trainCase),
    ('Title Case', value.titleCase),
    ('Sentence case', value.sentenceCase),
    ('dot.case', value.dotCase),
    ('path/case', value.pathCase),
    ('lower case', value.lowerCase),
    ('UPPER CASE', value.upperCase),
  ];
}
