import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/hash_parser.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class HashBody extends StatefulWidget implements ToolBodyWidget {
  const HashBody({
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
  State<HashBody> createState() => _HashBodyState();
}

class _HashBodyState extends State<HashBody> with ToolBodyScaffold<HashBody> {
  final TextEditingController _expectController = TextEditingController();

  String _md5 = '';
  String _sha1 = '';
  String _sha256 = '';
  String _sha512 = '';
  String? _matchLabel;

  @override
  String get utilityId => 'hash';

  // The digest of empty input is meaningful (and shown), so every keystroke —
  // including clearing to empty — recomputes rather than resetting.
  @override
  bool isBlank(String input) => false;

  @override
  void didUpdateWidget(HashBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) bindActionBar();
  }

  @override
  void dispose() {
    _expectController.dispose();
    super.dispose();
  }

  void _onExpectChanged(String _) {
    setState(() => _matchLabel = _findMatch());
  }

  @override
  void parse(String input) {
    final List<int> bytes = utf8.encode(input);
    setState(() {
      _md5 = HashTool.md5Hex(bytes);
      _sha1 = HashTool.sha1Hex(bytes);
      _sha256 = HashTool.sha256Hex(bytes);
      _sha512 = HashTool.sha512Hex(bytes);
      _matchLabel = _findMatch();
    });
    if (input.isNotEmpty) {
      recordOutput(input, _sha256);
    }
  }

  @override
  void reset() {
    _expectController.clear();
    setState(() {
      _md5 = '';
      _sha1 = '';
      _sha256 = '';
      _sha512 = '';
      _matchLabel = null;
    });
  }

  String? _findMatch() {
    final String expect = _expectController.text.trim().toLowerCase();
    if (expect.isEmpty) return null;
    if (expect == _md5) return 'MD5';
    if (expect == _sha1) return 'SHA-1';
    if (expect == _sha256) return 'SHA-256';
    if (expect == _sha512) return 'SHA-512';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Input',
          placeholder: 'Text to hash',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Digests'),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'MD5', value: _md5, accent: _matchLabel == 'MD5'),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'SHA-1',
          value: _sha1,
          accent: _matchLabel == 'SHA-1',
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'SHA-256',
          value: _sha256,
          accent: _matchLabel == 'SHA-256',
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'SHA-512',
          value: _sha512,
          accent: _matchLabel == 'SHA-512',
        ),
        const SizedBox(height: MqSpacing.lg),
        MqInput(
          controller: _expectController,
          label: 'Verify',
          placeholder: 'Paste expected digest to compare',
          onChanged: _onExpectChanged,
          multiline: false,
        ),
        if (controller.text.isNotEmpty)
          OpenInFooter(
            output: _sha256,
            excludeUtilityId: 'hash',
            onSwitchTool: widget.onSwitchTool,
          ),
      ],
    );
  }
}
