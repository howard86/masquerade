import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/json_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/mq_status.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

enum JSONMode { pretty, minify, tree }

class JSONBody extends StatefulWidget {
  const JSONBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;

  @override
  State<JSONBody> createState() => _JSONBodyState();
}

class _JSONBodyState extends State<JSONBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  JSONMode _mode = JSONMode.pretty;
  JSONParseResult? _result;

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
      setState(() => _result = null);
      return;
    }
    final JSONParseResult result = JSONParser.parse(input);
    setState(() => _result = result);
    if (result is JSONOk) {
      _recorder?.record(input, JSONParser.minify(result.value.value));
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
    setState(() => _result = null);
  }

  String _formatOutput(Object? value) => switch (_mode) {
    JSONMode.pretty => JSONParser.pretty(value),
    JSONMode.minify => JSONParser.minify(value),
    JSONMode.tree => _renderTree(value, 0),
  };

  static String _renderTree(Object? v, int depth) {
    final String indent = '  ' * depth;
    if (v is Map) {
      if (v.isEmpty) return '{}';
      final List<String> lines = <String>['{'];
      v.forEach((Object? k, Object? val) {
        lines.add('$indent  $k: ${_renderTree(val, depth + 1)}');
      });
      lines.add('$indent}');
      return lines.join('\n');
    }
    if (v is List) {
      if (v.isEmpty) return '[]';
      final List<String> lines = <String>['['];
      for (int i = 0; i < v.length; i++) {
        lines.add('$indent  [$i] ${_renderTree(v[i], depth + 1)}');
      }
      lines.add('$indent]');
      return lines.join('\n');
    }
    return '$v';
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
        const SizedBox(height: MqSpacing.md),
        MqSegmented<JSONMode>(
          options: const <JSONMode, String>{
            JSONMode.pretty: 'Pretty',
            JSONMode.minify: 'Minify',
            JSONMode.tree: 'Tree',
          },
          selected: _mode,
          onChanged: (JSONMode m) => setState(() => _mode = m),
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_result is JSONErr) ...<Widget>[
          MqStatus(
            label:
                'Error · line ${(_result! as JSONErr).error.line} col ${(_result! as JSONErr).error.column}',
            kind: MqStatusKind.danger,
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Reason',
            value: (_result! as JSONErr).error.message,
            copyable: false,
          ),
        ] else if (_result is JSONOk) ...<Widget>[
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: _mode.name.toUpperCase(),
            value: _formatOutput((_result! as JSONOk).value.value),
          ),
          OpenInFooter(
            output: JSONParser.minify((_result! as JSONOk).value.value),
            excludeUtilityId: 'json',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          const MqEmptyHint(label: 'Paste JSON to format or validate.'),
        const SizedBox(height: MqSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: MqButton(
                label: 'Paste',
                icon: MqIcons.paste,
                variant: MqButtonVariant.glass,
                onPressed: _paste,
                full: true,
              ),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: MqButton(
                label: 'Clear',
                icon: MqIcons.clear,
                variant: MqButtonVariant.glass,
                onPressed: _clear,
                full: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
