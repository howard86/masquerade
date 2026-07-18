import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/artifact.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/log_stack_inspector.dart';
import '../mq/mq_button.dart';
import '../mq/mq_input.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_body_scaffold.dart';

class LogStackInspectorBody extends StatefulWidget implements ToolBodyWidget {
  const LogStackInspectorBody({
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
  State<LogStackInspectorBody> createState() => _LogStackInspectorBodyState();
}

class _LogStackInspectorBodyState extends State<LogStackInspectorBody>
    with ToolBodyScaffold<LogStackInspectorBody> {
  final TextEditingController _search = TextEditingController();
  final Set<LogLevel> _levels = <LogLevel>{};
  final Map<int, int> _eventPreviewLimits = <int, int>{};
  LogInspection? _inspection;
  String? _error;
  int _visibleLimit = 50;

  @override
  String get utilityId => 'log_stack_inspector';

  @override
  Duration get debounceDuration => const Duration(milliseconds: 250);

  @override
  void parse(String input) {
    try {
      setState(() {
        _inspection = LogStackInspector.parse(input);
        _error = null;
        _visibleLimit = 50;
        _eventPreviewLimits.clear();
      });
    } on LogInspectorException catch (error) {
      setState(() {
        _inspection = null;
        _error = error.message;
      });
    }
  }

  @override
  void reset() => setState(() {
    _inspection = null;
    _error = null;
    _levels.clear();
    _search.clear();
    _eventPreviewLimits.clear();
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LogEvent> _filtered(LogInspection inspection) {
    try {
      return inspection.filter(levels: _levels, query: _search.text);
    } on LogInspectorException {
      return const <LogEvent>[];
    }
  }

  void _toggle(LogLevel level) => setState(() {
    _visibleLimit = 50;
    if (!_levels.remove(level)) _levels.add(level);
  });

  Future<void> _share(String text, String subject) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (_) {
      // Sharing is best effort; the same safe text remains copyable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final LogInspection? inspection = _inspection;
    final List<LogEvent> events = inspection == null
        ? const <LogEvent>[]
        : _filtered(inspection);
    final List<LogEvent> visibleEvents = events.take(_visibleLimit).toList();
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final bool protectedLineage =
        widget.initialArtifact?.isSensitive == true ||
        inspection?.hadSensitiveInput == true ||
        route?.protectedSession == true;
    final bool mayRoute =
        !protectedLineage ||
        (route?.addNext == true && route?.protectedSession == true);
    final String subset = inspection?.export(events) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          label: 'Logs or stack trace',
          placeholder: 'Paste JSON Lines, plain logs, or a stack trace…',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          onChanged: onInputChanged,
          onPaste: (_) => markPaste(),
          semanticsLabel:
              'Log input. Secrets are removed before previews and exports.',
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label: 'Local inspection only — secrets are redacted before output',
          kind: MqStatusKind.info,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          MqStatus(label: _error!, kind: MqStatusKind.danger),
        ],
        if (inspection != null) ...<Widget>[
          const SizedBox(height: MqSpacing.lg),
          MqSectionHeader(
            label: '${events.length} of ${inspection.events.length} events',
          ),
          if (inspection.truncated || inspection.hadSensitiveInput) ...<Widget>[
            MqStatus(
              label: inspection.truncated ? 'Bounds reached' : 'Redacted',
              kind: MqStatusKind.warning,
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
          MqInput(
            controller: _search,
            label: 'Search safe events',
            placeholder: 'Up to 256 characters',
            error: _search.text.length > LogStackInspector.maxSearchCharacters
                ? 'Search is too long.'
                : null,
            onChanged: (_) => setState(() => _visibleLimit = 50),
            semanticsLabel: 'Search redacted log events',
          ),
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              for (final LogLevel level in LogLevel.values)
                MqButton(
                  label: _levelLabel(level),
                  semanticsLabel:
                      '${_levels.contains(level) ? 'Remove' : 'Add'} ${_levelLabel(level)} filter',
                  variant: _levels.contains(level)
                      ? MqButtonVariant.tinted
                      : MqButtonVariant.glass,
                  size: MqButtonSize.sm,
                  onPressed: () => _toggle(level),
                ),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              MqButton(
                label: 'Copy filtered',
                icon: CupertinoIcons.doc_on_doc,
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: subset.isEmpty
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: subset)),
              ),
              MqButton(
                label: 'Share filtered',
                icon: CupertinoIcons.share,
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: subset.isEmpty
                    ? null
                    : () => _share(subset, 'Redacted log events'),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.lg),
          MqStatus(
            label:
                'Showing ${visibleEvents.length} of ${events.length} filtered events',
            kind: MqStatusKind.info,
          ),
          const SizedBox(height: MqSpacing.md),
          for (final LogEvent event in visibleEvents) ...<Widget>[
            _EventCard(
              key: ValueKey<int>(event.startLine),
              event: event,
              query: _search.text,
              previewLimit: _eventPreviewLimits[event.startLine] ?? 8192,
              mayRoute: mayRoute,
              onSwitchTool: widget.onSwitchTool,
              onShare: () => _share(event.text, 'Redacted log event'),
              onShowMore: () => setState(
                () => _eventPreviewLimits[event.startLine] =
                    (_eventPreviewLimits[event.startLine] ?? 8192) + 8192,
              ),
            ),
            const SizedBox(height: MqSpacing.md),
          ],
          if (visibleEvents.length < events.length)
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'Show 50 more',
                semanticsLabel: 'Show 50 more filtered events',
                variant: MqButtonVariant.glass,
                onPressed: () => setState(() => _visibleLimit += 50),
              ),
            ),
        ],
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    super.key,
    required this.event,
    required this.query,
    required this.previewLimit,
    required this.mayRoute,
    required this.onSwitchTool,
    required this.onShare,
    required this.onShowMore,
  });

  final LogEvent event;
  final String query;
  final int previewLimit;
  final bool mayRoute;
  final OpenInToolCallback? onSwitchTool;
  final VoidCallback onShare;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.mq.colors;
    final String lines = event.startLine == event.endLine
        ? 'Line ${event.startLine}'
        : 'Lines ${event.startLine}–${event.endLine}';
    final UtilityDescriptor target = UtilityCatalog.byId('artifact_inspector');
    final bool previewTruncated = event.text.length > previewLimit;
    final String preview = _eventPreview(event.text, query, previewLimit);
    return MqSurface(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$lines · ${_levelLabel(event.level)}'.toUpperCase(),
            style: MqTextStyles.sectionLabel.copyWith(color: colors.textSec),
          ),
          const SizedBox(height: MqSpacing.sm),
          if (event.normalizedTimestamp.isNotEmpty) ...<Widget>[
            Text(
              event.normalizedTimestamp,
              style: MqTextStyles.caption1.copyWith(color: colors.textSec),
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
          Text.rich(
            _highlight(preview, query, colors.textPri, colors.accent),
            style: MqTextStyles.monoSm.copyWith(color: colors.textPri),
          ),
          if (previewTruncated) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            const MqStatus(
              label:
                  'Preview truncated — copy and share include the full safe event',
              kind: MqStatusKind.info,
            ),
          ],
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: <Widget>[
              MqButton(
                label: 'Copy event',
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: event.text)),
              ),
              MqButton(
                label: 'Share event',
                variant: MqButtonVariant.glass,
                size: MqButtonSize.sm,
                onPressed: onShare,
              ),
              if (previewTruncated)
                MqButton(
                  label: 'Show more event',
                  semanticsLabel: 'Show more of this safe event preview',
                  variant: MqButtonVariant.glass,
                  size: MqButtonSize.sm,
                  onPressed: onShowMore,
                ),
              for (final (int index, String artifact)
                  in event.artifacts.indexed)
                if (mayRoute && onSwitchTool != null)
                  MqButton(
                    label: event.artifacts.length == 1
                        ? 'Open in Artifact Inspector'
                        : 'Open artifact ${index + 1}',
                    semanticsLabel:
                        'Open safe artifact ${index + 1} in Artifact Inspector',
                    variant: MqButtonVariant.tinted,
                    size: MqButtonSize.sm,
                    onPressed: () => onSwitchTool!(target, artifact),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

String _eventPreview(String text, String query, int limit) {
  if (text.length <= limit) return text;
  int start = 0;
  if (query.isNotEmpty &&
      query.length <= LogStackInspector.maxSearchCharacters) {
    final Match? match = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (match != null && match.start >= limit) {
      start = (match.start - limit ~/ 2).clamp(0, text.length - limit);
    }
  }
  if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start--;
  int end = start + limit;
  if (end < text.length && _isLowSurrogate(text.codeUnitAt(end))) end++;
  return '${start > 0 ? '…' : ''}${text.substring(start, end)}…';
}

bool _isLowSurrogate(int code) => code >= 0xdc00 && code <= 0xdfff;

TextSpan _highlight(String text, String query, Color normal, Color accent) {
  if (query.isEmpty || query.length > LogStackInspector.maxSearchCharacters) {
    return TextSpan(
      text: text,
      style: TextStyle(color: normal),
    );
  }
  final List<TextSpan> spans = <TextSpan>[];
  int start = 0;
  final RegExp needle = RegExp(
    RegExp.escape(query),
    caseSensitive: false,
    unicode: true,
  );
  for (final Match match in needle.allMatches(text)) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(color: accent, fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(
    style: TextStyle(color: normal),
    children: spans,
  );
}

String _levelLabel(LogLevel level) => switch (level) {
  LogLevel.trace => 'TRACE',
  LogLevel.debug => 'DEBUG',
  LogLevel.info => 'INFO',
  LogLevel.warn => 'WARN',
  LogLevel.error => 'ERROR',
  LogLevel.fatal => 'FATAL',
  LogLevel.unknown => 'UNKNOWN',
};
