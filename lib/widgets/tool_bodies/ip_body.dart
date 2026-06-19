import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/ip_parser.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/tool_action_bar.dart';
import 'copy_all_button.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class IpBody extends StatefulWidget implements ToolBodyWidget {
  const IpBody({
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
  final LinkChannel? link;

  @override
  State<IpBody> createState() => _IpBodyState();
}

class _IpBodyState extends State<IpBody> with ToolBodyScaffold<IpBody> {
  IpParseResult? _result;

  @override
  String get utilityId => 'ip';

  @override
  void didUpdateWidget(IpBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) bindActionBar();
  }

  @override
  void parse(String input) {
    final String trimmed = input.trim();
    final IpParseResult result = IpParser.parse(trimmed);
    setState(() => _result = result);
    if (result is IpOk) {
      recordOutput(trimmed, _formatSummary(result));
    }
  }

  @override
  void reset() {
    setState(() => _result = null);
  }

  /// Copies every output cell (Canonical/Family/subnet rows/…) at once, in the
  /// order they render. Hidden until a valid address parses, so the action bar
  /// shows it only when there is output to copy.
  @override
  Widget? actionBarCenter() {
    final IpParseResult? r = _result;
    if (r is! IpOk) return null;
    return CopyAllButton(payload: _outputValues(r).join('\n'));
  }

  /// The copyable mono-cell values for [ok], in display order — mirrors the
  /// rows built by [_buildOk] (scope chips are labels, not output, so omitted).
  List<String> _outputValues(IpOk ok) {
    final bool v4 = ok.family == IpFamily.v4;
    String fmt(BigInt n) => v4 ? IpParser.formatV4(n) : IpParser.formatV6(n);
    return <String>[
      fmt(ok.address),
      v4 ? 'IPv4' : 'IPv6',
      if (ok.prefix != null) '/${ok.prefix}',
      if (!v4) IpParser.formatV6(ok.address, compress: false),
      if (ok.prefix != null) ...<String>[
        fmt(ok.network!),
        if (v4) IpParser.formatV4(ok.broadcast!),
        fmt(ok.firstHost!),
        fmt(ok.lastHost!),
        ok.hostCount.toString(),
        if (ok.netmask != null) ok.netmask!,
      ],
    ];
  }

  String _formatSummary(IpOk ok) {
    if (ok.family == IpFamily.v4) return IpParser.formatV4(ok.address);
    return IpParser.formatV6(ok.address);
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
          controller: controller,
          label: 'Address',
          placeholder: '192.168.1.0/24 or 2001:db8::1',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
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
      if (controller.text.isNotEmpty)
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
