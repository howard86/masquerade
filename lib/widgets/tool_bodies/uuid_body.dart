import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/uuid_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class UuidBody extends StatefulWidget {
  const UuidBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;
  final LinkChannel? link;

  @override
  State<UuidBody> createState() => _UuidBodyState();
}

class _UuidBodyState extends State<UuidBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  UuidParseResult? _result;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
  }

  @override
  void didUpdateWidget(UuidBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) _updateActionBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'uuid',
      );
      if (widget.seedSource == SeedSource.paste) _recorder!.markPaste();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateActionBar() {
    widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _parse);
  }

  void _parse() {
    final String input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _result = null);
      return;
    }
    final UuidParseResult result = UuidParser.parse(input);
    setState(() => _result = result);
    if (result is UuidOk) {
      _recorder?.record(input, result.canonical);
    } else if (result is UlidOk) {
      _recorder?.record(input, result.canonical);
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

  void _generateV4() {
    _controller.text = UuidParser.generateV4();
    _recorder?.markPaste();
    _parse();
  }

  void _generateV7() {
    _controller.text = UuidParser.generateV7();
    _recorder?.markPaste();
    _parse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'UUID / ULID',
          placeholder: '550e8400-e29b-41d4-a716-446655440000',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            MqButton(
              label: 'Generate v4',
              onPressed: _generateV4,
              variant: MqButtonVariant.tinted,
              size: MqButtonSize.sm,
            ),
            MqButton(
              label: 'Generate v7',
              onPressed: _generateV7,
              variant: MqButtonVariant.tinted,
              size: MqButtonSize.sm,
            ),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_result is UuidErr)
          MqMonoCell(
            label: 'Error',
            value: (_result! as UuidErr).message,
            copyable: false,
          )
        else if (_result is UuidOk)
          ..._buildUuidOk(_result! as UuidOk)
        else if (_result is UlidOk)
          ..._buildUlidOk(_result! as UlidOk)
        else
          const MqEmptyHint(label: 'Enter a UUID or ULID, or generate one.'),
      ],
    );
  }

  List<Widget> _buildUuidOk(UuidOk ok) {
    final String noDashes = ok.canonical.replaceAll('-', '');
    return <Widget>[
      MqMonoCell(label: 'Canonical', value: ok.canonical),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'No-dashes', value: noDashes),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Uppercase', value: ok.canonical.toUpperCase()),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Version', value: ok.version.toString()),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Variant', value: ok.variant.toString()),
      if (ok.timestamp != null) ...<Widget>[
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'Timestamp', value: ok.timestamp!.toIso8601String()),
      ],
      if (ok.timestamp != null)
        OpenInFooter(
          output: ok.timestamp!.toIso8601String(),
          excludeUtilityId: 'uuid',
          onSwitchTool: widget.onSwitchTool,
        ),
    ];
  }

  List<Widget> _buildUlidOk(UlidOk ok) {
    return <Widget>[
      MqMonoCell(label: 'Canonical', value: ok.canonical),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Timestamp', value: ok.timestamp.toIso8601String()),
      OpenInFooter(
        output: ok.timestamp.toIso8601String(),
        excludeUtilityId: 'uuid',
        onSwitchTool: widget.onSwitchTool,
      ),
    ];
  }
}
