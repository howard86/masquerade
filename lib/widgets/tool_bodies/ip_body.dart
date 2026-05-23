import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/ip_parser.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class IpBody extends StatefulWidget {
  const IpBody({
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
  State<IpBody> createState() => _IpBodyState();
}

class _IpBodyState extends State<IpBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  IpParseResult? _result;
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
  void didUpdateWidget(IpBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) _updateActionBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'ip',
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
    final IpParseResult result = IpParser.parse(input);
    setState(() => _result = result);
    if (result is IpOk) {
      _recorder?.record(input, _formatSummary(result));
    }
  }

  String _formatSummary(IpOk ok) {
    if (ok.family == IpFamily.v4) return IpParser.formatV4(ok.address);
    return IpParser.formatV6(ok.address);
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

  String _hexAddress(IpOk ok) {
    if (ok.family == IpFamily.v4) {
      return '0x${ok.address.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    return '0x${ok.address.toRadixString(16).padLeft(32, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Address',
          placeholder: '192.168.1.0/24 or 2001:db8::1',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_result is IpErr)
          MqMonoCell(
            label: 'Error',
            value: (_result! as IpErr).message,
            copyable: false,
          )
        else if (_result is IpOk)
          ..._buildOk(_result! as IpOk)
        else
          const MqEmptyHint(
            label: 'Enter an IPv4 or IPv6 address, with optional CIDR prefix.',
          ),
      ],
    );
  }

  List<Widget> _buildOk(IpOk ok) {
    final String canonical = ok.family == IpFamily.v4
        ? IpParser.formatV4(ok.address)
        : IpParser.formatV6(ok.address);

    return <Widget>[
      const MqSectionHeader(label: 'Address'),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Canonical', value: canonical),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(
        label: 'Family',
        value: ok.family == IpFamily.v4 ? 'IPv4' : 'IPv6',
      ),
      if (ok.prefix != null) ...<Widget>[
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'Prefix', value: '/${ok.prefix}'),
      ],
      if (ok.family == IpFamily.v6) ...<Widget>[
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Expanded',
          value: IpParser.formatV6(ok.address, compress: false),
        ),
      ],
      if (ok.prefix != null) ...<Widget>[
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Subnet'),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Network',
          value: ok.family == IpFamily.v4
              ? IpParser.formatV4(ok.network!)
              : IpParser.formatV6(ok.network!),
        ),
        if (ok.family == IpFamily.v4) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Broadcast',
            value: IpParser.formatV4(ok.broadcast!),
          ),
        ],
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'First host',
          value: ok.family == IpFamily.v4
              ? IpParser.formatV4(ok.firstHost!)
              : IpParser.formatV6(ok.firstHost!),
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(
          label: 'Last host',
          value: ok.family == IpFamily.v4
              ? IpParser.formatV4(ok.lastHost!)
              : IpParser.formatV6(ok.lastHost!),
        ),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'Host count', value: ok.hostCount.toString()),
        if (ok.netmask != null) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Netmask', value: ok.netmask!),
        ],
      ],
      if (ok.scopes.isNotEmpty &&
          !(ok.scopes.length == 1 &&
              ok.scopes.contains(IpScope.unspecified))) ...<Widget>[
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Scope'),
        const SizedBox(height: MqSpacing.sm),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            for (final IpScope scope in ok.scopes)
              if (scope != IpScope.unspecified)
                MqChip(label: _scopeLabel(scope), mono: false),
          ],
        ),
      ],
      if (_controller.text.isNotEmpty)
        OpenInFooter(
          output: _hexAddress(ok),
          excludeUtilityId: 'ip',
          onSwitchTool: widget.onSwitchTool,
        ),
    ];
  }

  String _scopeLabel(IpScope scope) => switch (scope) {
    IpScope.private => 'Private',
    IpScope.loopback => 'Loopback',
    IpScope.linkLocal => 'Link-local',
    IpScope.multicast => 'Multicast',
    IpScope.documentation => 'Documentation',
    IpScope.unspecified => 'Unspecified',
  };
}
