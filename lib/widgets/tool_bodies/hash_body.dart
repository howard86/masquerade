import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/hash_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class HashBody extends StatefulWidget {
  const HashBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  @override
  State<HashBody> createState() => _HashBodyState();
}

class _HashBodyState extends State<HashBody> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _expectController = TextEditingController();
  Timer? _debounce;

  String _md5 = '';
  String _sha1 = '';
  String _sha256 = '';
  String _sha512 = '';
  String? _matchLabel;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compute();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
  }

  @override
  void didUpdateWidget(HashBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) _updateActionBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'hash',
      );
      if (widget.seedSource == SeedSource.paste) _recorder!.markPaste();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    _expectController.dispose();
    super.dispose();
  }

  void _updateActionBar() {
    widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _compute);
  }

  void _onExpectChanged(String _) {
    setState(() => _matchLabel = _findMatch());
  }

  void _compute() {
    final List<int> bytes = utf8.encode(_controller.text);
    setState(() {
      _md5 = HashTool.md5Hex(bytes);
      _sha1 = HashTool.sha1Hex(bytes);
      _sha256 = HashTool.sha256Hex(bytes);
      _sha512 = HashTool.sha512Hex(bytes);
      _matchLabel = _findMatch();
    });
    if (_controller.text.isNotEmpty) {
      _recorder?.record(_controller.text, _sha256);
    }
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

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _recorder?.markPaste();
    _compute();
  }

  void _clear() {
    _controller.clear();
    _expectController.clear();
    setState(() {
      _md5 = '';
      _sha1 = '';
      _sha256 = '';
      _sha512 = '';
      _matchLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: 'Text to hash',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
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
        if (_controller.text.isNotEmpty)
          OpenInFooter(
            output: _sha256,
            excludeUtilityId: 'hash',
            onSwitchTool: widget.onSwitchTool,
          ),
      ],
    );
  }
}
