import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/copy_util.dart';
import '../../utils/x509_inspector.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'copy_all_button.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class X509InspectorBody extends StatefulWidget implements ToolBodyWidget {
  X509InspectorBody({
    super.key,
    String? initialInput,
    Artifact<Object?>? initialArtifact,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  }) : _privateKeyDetected =
           X509Inspector.containsPrivateKey(initialInput ?? '') ||
           X509Inspector.containsPrivateKey(initialArtifact?.rawValue ?? ''),
       _initialInput = X509Inspector.containsPrivateKey(initialInput ?? '')
           ? null
           : initialInput,
       initialArtifact =
           X509Inspector.containsPrivateKey(initialArtifact?.rawValue ?? '')
           ? null
           : initialArtifact;

  final String? _initialInput;
  final bool _privateKeyDetected;
  final Artifact<Object?>? initialArtifact;

  @override
  String? get initialInput => _initialInput;

  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;

  @override
  State<X509InspectorBody> createState() => _X509InspectorBodyState();
}

class _X509InspectorBodyState extends State<X509InspectorBody>
    with ToolBodyScaffold<X509InspectorBody> {
  X509Inspection? _inspection;
  String? _error;

  @override
  String get utilityId => 'x509_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    if (widget._privateKeyDetected) {
      _error = privateKeyWarning;
    }
  }

  void _onChanged(String value) {
    if (X509Inspector.containsPrivateKey(value)) {
      _rejectPrivateKey();
      return;
    }
    onInputChanged(value);
  }

  void _onPaste(String value) {
    if (X509Inspector.containsPrivateKey(value)) {
      _rejectPrivateKey();
    } else {
      markPaste();
    }
  }

  void _rejectPrivateKey() {
    clearInput();
    setState(() {
      _inspection = null;
      _error = privateKeyWarning;
    });
  }

  @override
  Future<void> pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null) return;
    if (X509Inspector.containsPrivateKey(text)) {
      _rejectPrivateKey();
    } else {
      setInput(text);
    }
  }

  @override
  void parse(String input) {
    try {
      final X509Inspection inspection = X509Inspector.parse(input);
      setState(() {
        _inspection = inspection;
        _error = null;
      });
    } on X509InspectorException catch (error) {
      if (error.privateKey) {
        _rejectPrivateKey();
      } else {
        setState(() {
          _inspection = null;
          _error = error.message;
        });
      }
    }
  }

  @override
  void reset() => setState(() {
    _inspection = null;
    _error = null;
  });

  /// Copies every certificate's Subject/Issuer/Valid from/Valid until/SANs/
  /// Public key/fingerprints, in chain order. Hidden until a certificate
  /// parses, so the action bar shows it only when there is output to copy.
  @override
  Widget? actionBarCenter() {
    final X509Inspection? inspection = _inspection;
    if (inspection == null || inspection.certificates.isEmpty) return null;
    return CopyAllButton(payload: _outputValues(inspection).join('\n'));
  }

  /// The copyable values for [inspection], in display order — mirrors the
  /// rows built by [_CertificateCard] for every certificate in the chain.
  List<String> _outputValues(X509Inspection inspection) => <String>[
    for (final X509CertificateInfo cert in inspection.certificates) ...<String>[
      cert.subject,
      cert.issuer,
      cert.notBefore.toIso8601String(),
      cert.notAfter.toIso8601String(),
      if (cert.sans.isNotEmpty) cert.sans.join('\n'),
      cert.keyDescription,
      _fingerprint(cert.sha1Hex),
      _fingerprint(cert.sha256Hex),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final X509Inspection? inspection = _inspection;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        route?.protectedSession == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Certificate',
          placeholder: 'Paste CERTIFICATE PEM, base64:DER, or hex:DER…',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          onChanged: _onChanged,
          onPaste: _onPaste,
          semanticsLabel:
              'X.509 certificate input. Private keys are immediately removed.',
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label: 'Local inspection only — no certificate is fetched or sent',
          kind: MqStatusKind.info,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (inspection != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          MqSectionHeader(
            label: inspection.certificates.length == 1
                ? 'Certificate'
                : '${inspection.certificates.length}-certificate chain',
          ),
          for (final (int index, X509CertificateInfo certificate)
              in inspection.certificates.indexed) ...<Widget>[
            if (index > 0) const SizedBox(height: MqSpacing.md),
            _CertificateCard(
              index: index,
              certificate: certificate,
              protectedLineage: protectedLineage,
              onSwitchTool: widget.onSwitchTool,
            ),
          ],
          const SizedBox(height: MqSpacing.md),
          for (final String warning in inspection.warnings) ...<Widget>[
            MqStatus(label: warning, kind: MqStatusKind.warning),
            const SizedBox(height: MqSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.index,
    required this.certificate,
    required this.protectedLineage,
    required this.onSwitchTool,
  });

  final int index;
  final X509CertificateInfo certificate;
  final bool protectedLineage;
  final OpenInToolCallback? onSwitchTool;

  @override
  Widget build(BuildContext context) {
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool mayRoute =
        onSwitchTool != null &&
        (!protectedLineage ||
            (route?.addNext == true && route?.protectedSession == true));
    final String action = route?.addNext == true ? 'Add next' : 'Open in';
    final List<(String, String, String)> routes = <(String, String, String)>[
      ('Not before', 'timestamp', certificate.notBefore.toIso8601String()),
      ('Not after', 'timestamp', certificate.notAfter.toIso8601String()),
      ('SHA-1', 'hash', certificate.sha1Hex),
      ('SHA-256', 'hash', certificate.sha256Hex),
      ('DER', 'bytes', certificate.bytesInput),
    ];

    return MqSurface(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MqSectionHeader(label: 'Certificate ${index + 1}'),
          MqMonoCell(label: 'Subject', value: certificate.subject),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Issuer', value: certificate.issuer),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Valid from',
            value: certificate.notBefore.toIso8601String(),
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'Valid until',
            value: certificate.notAfter.toIso8601String(),
          ),
          if (certificate.sans.isNotEmpty) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(label: 'SANs', value: certificate.sans.join('\n')),
          ],
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(label: 'Public key', value: certificate.keyDescription),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'SHA-1 fingerprint',
            value: _fingerprint(certificate.sha1Hex),
          ),
          const SizedBox(height: MqSpacing.sm),
          MqMonoCell(
            label: 'SHA-256 fingerprint',
            value: _fingerprint(certificate.sha256Hex),
          ),
          const SizedBox(height: MqSpacing.md),
          const MqSectionHeader(label: 'Convert'),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              _copyButton(context, 'Copy PEM', certificate.pem),
              _copyButton(context, 'Copy DER base64', certificate.derBase64),
              _copyButton(context, 'Copy DER hex', certificate.derHex),
            ],
          ),
          if (mayRoute) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            MqSectionHeader(label: action),
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              children: <Widget>[
                for (final (String field, String toolId, String value)
                    in routes)
                  MqButton(
                    label: '$field → ${UtilityCatalog.byId(toolId).name}',
                    semanticsLabel:
                        '$action ${UtilityCatalog.byId(toolId).name} with $field',
                    variant: MqButtonVariant.glass,
                    size: MqButtonSize.sm,
                    onPressed: () =>
                        onSwitchTool!(UtilityCatalog.byId(toolId), value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _copyButton(BuildContext context, String label, String value) =>
      MqButton(
        label: label,
        semanticsLabel: '$label certificate ${index + 1}',
        variant: MqButtonVariant.glass,
        size: MqButtonSize.sm,
        onPressed: () => CopyToClipboardUtil.copyToClipboard(
          context,
          value,
          sensitive: protectedLineage,
        ),
      );
}

String _fingerprint(String hex) => <String>[
  for (int index = 0; index < hex.length; index += 2)
    hex.substring(index, index + 2).toUpperCase(),
].join(':');
