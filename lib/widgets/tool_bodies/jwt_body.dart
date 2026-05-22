import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
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

class JwtBody extends StatefulWidget {
  const JwtBody({
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
  State<JwtBody> createState() => _JwtBodyState();
}

class _JwtBodyState extends State<JwtBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  JwtParseResult? _result;
  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _decode();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'jwt',
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

  void _updateActionBar() {
    widget.actionBar?.bind(onPaste: _paste, onClear: _clear);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _decode);
  }

  void _decode() {
    final String input = _controller.text;
    if (input.trim().isEmpty) {
      setState(() => _result = null);
      _updateActionBar();
      return;
    }
    final JwtParseResult result = JwtParser.parse(input.trim());
    setState(() => _result = result);
    if (result is JwtOk) {
      final String pretty = const JsonEncoder.withIndent(
        '  ',
      ).convert(result.payload);
      _recorder?.record(input, pretty);
    }
    _updateActionBar();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _recorder?.markPaste();
    _decode();
  }

  void _clear() {
    _controller.clear();
    setState(() => _result = null);
    _updateActionBar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _controller,
          label: 'Token',
          placeholder: 'Paste a JWT (header.payload.signature)',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
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
