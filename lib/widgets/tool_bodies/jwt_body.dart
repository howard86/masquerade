import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/jwt_parser.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class JwtBody extends StatefulWidget implements ToolBodyWidget {
  const JwtBody({
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
  State<JwtBody> createState() => _JwtBodyState();
}

class _JwtBodyState extends State<JwtBody> with ToolBodyScaffold<JwtBody> {
  JwtParseResult? _result;

  @override
  String get utilityId => 'jwt';

  @override
  void parse(String input) {
    final JwtParseResult result = JwtParser.parse(input.trim());
    setState(() => _result = result);
    if (result is JwtOk) {
      final String pretty = const JsonEncoder.withIndent(
        '  ',
      ).convert(result.payload);
      recordOutput(input, pretty);
    }
  }

  @override
  void reset() {
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Token',
          placeholder: 'Paste a JWT (header.payload.signature)',
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_result is JwtErr)
          MqMonoCell(
            label: 'Error',
            value: (_result! as JwtErr).message,
            copyable: false,
          )
        else if (_result is JwtOk)
          ..._buildOk(_result! as JwtOk, c)
        else
          const MqEmptyHint(label: 'Paste a JWT to decode its claims.'),
      ],
    );
  }

  List<Widget> _buildOk(JwtOk ok, dynamic c) {
    final String prettyHeader = const JsonEncoder.withIndent(
      '  ',
    ).convert(ok.header);
    final String prettyPayload = const JsonEncoder.withIndent(
      '  ',
    ).convert(ok.payload);

    return <Widget>[
      // Status banner
      if (ok.isExpired)
        const MqStatus(label: 'Expired', kind: MqStatusKind.danger)
      else if (ok.isNotYetValid)
        const MqStatus(label: 'Not yet valid', kind: MqStatusKind.warning)
      else
        const MqStatus(label: 'Valid window', kind: MqStatusKind.success),
      const SizedBox(height: MqSpacing.md),

      // Header section
      const MqSectionHeader(label: 'Header'),
      MqMonoCell(label: 'JSON', value: prettyHeader),
      const SizedBox(height: MqSpacing.sm),
      Wrap(
        spacing: MqSpacing.sm,
        runSpacing: MqSpacing.sm,
        children: <Widget>[
          if (ok.header['alg'] != null)
            MqChip(label: 'alg: ${ok.header['alg']}', mono: true),
          if (ok.header['typ'] != null)
            MqChip(label: 'typ: ${ok.header['typ']}', mono: true),
          if (ok.header['kid'] != null)
            MqChip(label: 'kid: ${ok.header['kid']}', mono: true),
        ],
      ),
      const SizedBox(height: MqSpacing.lg),

      // Payload section
      const MqSectionHeader(label: 'Payload'),
      MqMonoCell(label: 'JSON', value: prettyPayload, accent: true),
      const SizedBox(height: MqSpacing.sm),
      Wrap(
        spacing: MqSpacing.sm,
        runSpacing: MqSpacing.sm,
        children: <Widget>[
          if (ok.payload['iss'] != null)
            MqChip(label: 'iss: ${ok.payload['iss']}', mono: true),
          if (ok.payload['sub'] != null)
            MqChip(label: 'sub: ${ok.payload['sub']}', mono: true),
          if (ok.payload['aud'] != null)
            MqChip(label: 'aud: ${ok.payload['aud']}', mono: true),
          if (ok.payload['jti'] != null)
            MqChip(label: 'jti: ${ok.payload['jti']}', mono: true),
          if (ok.issuedAt != null)
            MqChip(label: 'iat: ${ok.issuedAt!.toIso8601String()}', mono: true),
          if (ok.notBefore != null)
            MqChip(
              label: 'nbf: ${ok.notBefore!.toIso8601String()}',
              mono: true,
            ),
          if (ok.expiresAt != null)
            MqChip(
              label: 'exp: ${ok.expiresAt!.toIso8601String()}',
              mono: true,
            ),
        ],
      ),
      const SizedBox(height: MqSpacing.lg),

      // Signature section
      const MqSectionHeader(label: 'Signature'),
      MqMonoCell(
        label: 'Base64url (${_sigByteLen(ok.signature)} bytes)',
        value: ok.signature.isEmpty ? '(empty — alg:none)' : ok.signature,
      ),
      const SizedBox(height: MqSpacing.md),

      // Decode-only disclaimer
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Decode-only — signature not verified.',
          style: MqTextStyles.caption1.copyWith(color: c.textTer),
        ),
      ),

      // Open in footer
      OpenInFooter(
        output: prettyPayload,
        excludeUtilityId: 'jwt',
        onSwitchTool: widget.onSwitchTool,
      ),
    ];
  }

  int _sigByteLen(String sig) {
    if (sig.isEmpty) return 0;
    String s = sig.replaceAll('-', '+').replaceAll('_', '/');
    final int rem = s.length % 4;
    if (rem != 0) s = s.padRight(s.length + (4 - rem), '=');
    try {
      return base64Decode(s).length;
    } catch (_) {
      return 0;
    }
  }
}
