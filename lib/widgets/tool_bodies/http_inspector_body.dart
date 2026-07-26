import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/http_request_inspector.dart';
import '../../utils/text_truncate.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class HttpInspectorBody extends StatefulWidget implements ToolBodyWidget {
  const HttpInspectorBody({
    super.key,
    this.initialInput,
    this.initialArtifact,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  @override
  final String? initialInput;
  final Artifact<Object?>? initialArtifact;
  @override
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  @override
  final ToolActionBarController? actionBar;

  @override
  State<HttpInspectorBody> createState() => _HttpInspectorBodyState();
}

class _HttpInspectorBodyState extends State<HttpInspectorBody>
    with ToolBodyScaffold<HttpInspectorBody> {
  HttpRequestDescriptor? _request;
  HttpConversionTarget _target = HttpConversionTarget.curl;
  String? _output;
  String? _error;

  @override
  String get utilityId => 'http_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 200);

  @override
  void parse(String input) {
    try {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(input);
      setState(() {
        _request = request;
        _error = null;
        _output = _convert(request, _target);
      });
    } on HttpInspectorException catch (error) {
      setState(() {
        _request = null;
        _output = null;
        _error = error.message;
      });
    }
  }

  String? _convert(HttpRequestDescriptor request, HttpConversionTarget target) {
    try {
      return HttpRequestInspector.convert(request, target);
    } on HttpInspectorException catch (error) {
      _error = error.message;
      return null;
    }
  }

  void _select(HttpConversionTarget target) {
    final HttpRequestDescriptor? request = _request;
    if (request == null) return;
    setState(() {
      _target = target;
      _error = null;
      _output = _convert(request, target);
    });
  }

  @override
  void reset() => setState(() {
    _request = null;
    _output = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final HttpRequestDescriptor? request = _request;
    final HttpRequestDescriptor? safe = request?.redacted;
    final String? output = _output;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        request?.hasSensitiveLineage == true ||
        route?.protectedSession == true;
    final bool mayRoute = !protectedLineage || route?.protectedSession == true;
    final String? body = safe?.body;
    final bool routableBody =
        body != null &&
        body != '[REDACTED]' &&
        (_isJson(safe?.contentType) ||
            safe?.contentType == 'application/x-www-form-urlencoded');
    final String? routableBodyValue = !routableBody
        ? null
        : safe?.contentType == 'application/x-www-form-urlencoded'
        ? '?$body'
        : body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Request',
          placeholder: 'Paste cURL, raw HTTP, Fetch, Axios, or a request log…',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          semanticsLabel: 'HTTP request source. Requests are never executed.',
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label: 'Local inspection only — requests are never sent',
          kind: MqStatusKind.info,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (safe != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          MqSectionHeader(
            label: '${request!.kind.name} · ${safe.method}',
            trailing: request.hasSensitiveLineage
                ? const MqStatus(label: 'Redacted', kind: MqStatusKind.warning)
                : null,
          ),
          MqMonoCell(label: 'URL', value: safe.redactedUrl, copyable: true),
          if (safe.headers.isNotEmpty || safe.cookies.isNotEmpty) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(
              label: 'Headers',
              value: <HttpField>[
                ...safe.headers,
                ...safe.cookies.map(
                  (HttpField f) => HttpField('Cookie ${f.name}', f.value),
                ),
              ].map((HttpField f) => '${f.name}: ${f.value}').join('\n'),
              copyable: true,
            ),
          ],
          if (body != null) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(
              label: safe.contentType ?? 'Body',
              value: truncateWithEllipsis(body, max: 4096),
              copyable: false,
            ),
          ],
          const SizedBox(height: MqSpacing.lg),
          const MqSectionHeader(label: 'Convert to'),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              for (final HttpConversionTarget target
                  in HttpConversionTarget.values)
                MqButton(
                  label: _targetLabel(target),
                  semanticsLabel: 'Convert request to ${_targetLabel(target)}',
                  variant: target == _target
                      ? MqButtonVariant.tinted
                      : MqButtonVariant.glass,
                  size: MqButtonSize.sm,
                  onPressed: () => _select(target),
                ),
            ],
          ),
          if (output != null) ...<Widget>[
            const SizedBox(height: MqSpacing.md),
            MqMonoCell(
              label: _targetLabel(_target),
              value: truncateWithEllipsis(output, max: 8192),
              copyable: false,
              accent: true,
            ),
            const SizedBox(height: MqSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'Copy redacted conversion',
                semanticsLabel:
                    'Copy full redacted ${_targetLabel(_target)} conversion',
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: () => Clipboard.setData(ClipboardData(text: output)),
              ),
            ),
          ],
          if (mayRoute) ...<Widget>[
            OpenInFooter(
              output: safe.redactedUrl,
              excludeUtilityId: utilityId,
              onSwitchTool: widget.onSwitchTool,
              protectedSource: protectedLineage,
            ),
            if (routableBody)
              OpenInFooter(
                output: routableBodyValue,
                excludeUtilityId: utilityId,
                onSwitchTool: widget.onSwitchTool,
                protectedSource: protectedLineage,
              ),
          ],
        ],
      ],
    );
  }
}

bool _isJson(String? contentType) =>
    contentType == 'application/json' || contentType?.endsWith('+json') == true;

String _targetLabel(HttpConversionTarget target) => switch (target) {
  HttpConversionTarget.curl => 'cURL',
  HttpConversionTarget.fetch => 'Fetch',
  HttpConversionTarget.axios => 'Axios',
  HttpConversionTarget.python => 'Python',
  HttpConversionTarget.go => 'Go',
  HttpConversionTarget.rust => 'Rust',
};
