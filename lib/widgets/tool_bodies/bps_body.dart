import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/bps_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';
import 'tool_layout.dart';

class BpsBody extends StatefulWidget implements ToolBodyWidget {
  const BpsBody({
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
  State<BpsBody> createState() => _BpsBodyState();
}

class _BpsBodyState extends State<BpsBody> with ToolBodyScaffold<BpsBody> {
  BpsResult? _result;
  String? _error;

  /// Canvas-only: the value pinned as a baseline; the Δ readout compares the
  /// current result against it. Null until the user pins.
  BpsResult? _baseline;

  @override
  String get utilityId => 'bps';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void parse(String input) {
    final BpsResult? parsed = BpsParser.parse(input);
    setState(() {
      _result = parsed;
      _error = parsed == null ? 'Could not parse as bps, % or decimal.' : null;
    });
    if (parsed != null) {
      recordOutput(input, '${parsed.bps.toStringAsFixed(2)} bps');
    }
  }

  @override
  void reset() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  void _pinBaseline() {
    if (_result == null) return;
    setState(() => _baseline = _result);
  }

  void _unpinBaseline() => setState(() => _baseline = null);

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kToolCanvasWide;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MqInput(
              controller: controller,
              label: 'Input',
              placeholder: '25 bps · 0.25% · 0.0025',
              onChanged: onInputChanged,
              onPaste: (_) => markPaste(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: MqSpacing.lg),
            if (_error != null)
              MqMonoCell(label: 'Error', value: _error!, copyable: false)
            else if (_result != null) ...<Widget>[
              const MqSectionHeader(label: 'Detected'),
              MqStatus(label: _result!.detected.name, kind: MqStatusKind.info),
              const SizedBox(height: MqSpacing.md),
              const MqSectionHeader(label: 'Output'),
              MqMonoCell(
                label: 'Basis points',
                value: _result!.bps.toStringAsFixed(2),
                accent: true,
                large: true,
              ),
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(
                label: 'Percent',
                value: '${_result!.percent.toStringAsFixed(4)}%',
              ),
              const SizedBox(height: MqSpacing.sm),
              MqMonoCell(
                label: 'Decimal',
                value: _result!.decimal.toStringAsFixed(6),
              ),
              // Canvas-only: pin a baseline and read the delta against it.
              // Hidden on phones (width < [kToolCanvasWide]), unchanged there.
              if (wide) ..._baselineSection(),
              const SizedBox(height: MqSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Reference only. Not financial advice. Annualization is implementation-dependent.',
                  style: MqTextStyles.caption1.copyWith(color: c.textTer),
                ),
              ),
              OpenInFooter(
                output: _result?.bps.toStringAsFixed(2),
                excludeUtilityId: 'bps',
                onSwitchTool: widget.onSwitchTool,
              ),
            ] else
              const MqEmptyHint(label: 'Paste a value with bps, % or decimal.'),
          ],
        );
      },
    );
  }

  /// Canvas-only baseline pin + Δ readout. Shipped without the secondary
  /// "quick-tape mode" (deferred — the running tape is non-trivial here).
  List<Widget> _baselineSection() {
    final BpsResult? base = _baseline;
    if (base == null) {
      return <Widget>[
        const SizedBox(height: MqSpacing.md),
        MqButton(
          label: 'Pin baseline',
          variant: MqButtonVariant.glass,
          size: MqButtonSize.sm,
          onPressed: _pinBaseline,
        ),
      ];
    }
    final double dBps = _result!.bps - base.bps;
    final String sign = dBps >= 0 ? '+' : '';
    return <Widget>[
      const SizedBox(height: MqSpacing.md),
      const MqSectionHeader(label: 'Δ vs baseline'),
      MqMonoCell(
        label: 'Baseline',
        value: '${base.bps.toStringAsFixed(2)} bps',
        copyable: false,
      ),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(
        label: 'Δ Basis points',
        value: '$sign${dBps.toStringAsFixed(2)}',
        accent: true,
      ),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(
        label: 'Δ Percent',
        value: '$sign${(dBps / 100.0).toStringAsFixed(4)}%',
      ),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(
        label: 'Δ Decimal',
        value: '$sign${(dBps / 10000.0).toStringAsFixed(6)}',
      ),
      const SizedBox(height: MqSpacing.sm),
      MqButton(
        label: 'Unpin',
        variant: MqButtonVariant.plain,
        size: MqButtonSize.sm,
        onPressed: _unpinBaseline,
      ),
    ];
  }
}
