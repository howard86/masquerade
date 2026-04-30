import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import '../../utils/json_parser.dart';
import '../../widgets/mb/mb_button.dart';
import '../../widgets/mb/mb_icons.dart';
import '../../widgets/mb/mb_input.dart';
import '../../widgets/mb/mb_mono_cell.dart';
import '../../widgets/mb/mb_section_header.dart';
import '../../widgets/mb/mb_segmented.dart';
import '../../widgets/mb/mb_status.dart';
import 'detail_scaffold.dart';

enum JSONMode { pretty, minify, tree }

class JSONScreen extends StatefulWidget {
  const JSONScreen({super.key});

  @override
  State<JSONScreen> createState() => _JSONScreenState();
}

class _JSONScreenState extends State<JSONScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  JSONMode _mode = JSONMode.pretty;
  JSONParseResult? _result;

  @override
  void dispose() {
    _debounce?.cancel();
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
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'json',
          input: input,
          output: JSONParser.minify(result.value.value),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
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
    final c = context.mb.colors;
    return MBDetailScaffold(
      title: 'JSON',
      subtitle: 'Pretty / Minify / Tree. Errors point to line:column.',
      bottomBar: Row(
        children: <Widget>[
          Expanded(
            child: MBButton(
              label: 'Paste',
              icon: MBIcons.paste,
              variant: MBButtonVariant.glass,
              onPressed: _paste,
              full: true,
            ),
          ),
          const SizedBox(width: MBSpacing.sm),
          Expanded(
            child: MBButton(
              label: 'Clear',
              icon: MBIcons.clear,
              variant: MBButtonVariant.glass,
              onPressed: _clear,
              full: true,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MBInput(
            controller: _controller,
            label: 'Input',
            placeholder: '{"hello": "world"}',
            onChanged: _onChanged,
            multiline: true,
            minLines: 4,
            maxLines: 10,
          ),
          const SizedBox(height: MBSpacing.md),
          MBSegmented<JSONMode>(
            options: const <JSONMode, String>{
              JSONMode.pretty: 'Pretty',
              JSONMode.minify: 'Minify',
              JSONMode.tree: 'Tree',
            },
            selected: _mode,
            onChanged: (JSONMode m) => setState(() => _mode = m),
          ),
          const SizedBox(height: MBSpacing.lg),
          if (_result is JSONErr) ...<Widget>[
            MBStatus(
              label:
                  'Error · line ${(_result! as JSONErr).error.line} col ${(_result! as JSONErr).error.column}',
              kind: MBStatusKind.danger,
            ),
            const SizedBox(height: MBSpacing.sm),
            MBMonoCell(
              label: 'Reason',
              value: (_result! as JSONErr).error.message,
              copyable: false,
            ),
          ] else if (_result is JSONOk) ...<Widget>[
            const MBSectionHeader(label: 'Output'),
            MBMonoCell(
              label: _mode.name.toUpperCase(),
              value: _formatOutput((_result! as JSONOk).value.value),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MBSpacing.lg),
              child: Text(
                'Paste JSON to format or validate.',
                style: MBTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
