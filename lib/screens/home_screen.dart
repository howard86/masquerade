import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/artifact.dart';
import '../models/saved_workflow.dart';
import '../models/work_session.dart';
import '../state/detection_preference_controller.dart';
import '../state/share_inbox_controller.dart';
import '../state/work_session_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../utils/copy_util.dart';
import '../utils/external_input_importer.dart';
import '../widgets/mq/compact_paste_bar.dart';
import '../widgets/mq/mq_button.dart';
import '../widgets/mq/mq_empty_hint.dart';
import '../widgets/mq/mq_icons.dart';
import '../widgets/mq/mq_surface.dart';
import '../widgets/mq/mq_status.dart';
import '../widgets/mq/section_rule.dart';
import 'detail/qr_scanner_route.dart';
import 'detail/tool_detail_route.dart';

enum _WorkbenchState { empty, artifact, search, unknown }

enum _StepAction {
  reopen,
  copy,
  share,
  replace,
  removeSubsequent,
  duplicate,
  branch,
}

typedef _DetectedSuggestion = ({
  DetectionMatch<Object?> match,
  UtilityDescriptor tool,
  bool primary,
});

/// Mobile capture surface. Library owns catalog browsing; Workbench only
/// suggests tools for the current explicit input.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenTool,
    this.navigationBar,
    this.externalInputImporter,
    this.importEnabled = true,
    this.qrScanner,
    this.onAppIntentFocus,
  });

  final OpenInToolCallback? onOpenTool;
  final ObstructingPreferredSizeWidget? navigationBar;
  final ExternalInputImporter? externalInputImporter;
  final bool importEnabled;
  final Future<String?> Function(BuildContext context)? qrScanner;
  final VoidCallback? onAppIntentFocus;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hero = TextEditingController();
  final FocusNode _heroFocus = FocusNode();
  bool _showRawText = false;
  ArtifactProvenance _provenance = ArtifactProvenance.typed;
  String? _importError;
  int _inputRevision = 0;
  int _importRequest = 0;
  final Set<String> _acceptingSharedItems = <String>{};
  bool _handlingAppIntents = false;

  @override
  void initState() {
    super.initState();
    _hero.addListener(_onHeroChange);
    _heroFocus.addListener(_rebuild);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ShareInboxController inbox = ShareInboxScope.of(context);
    if (!_handlingAppIntents && inbox.intentRequests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumeAppIntents());
    }
  }

  @override
  void dispose() {
    _hero.removeListener(_onHeroChange);
    _heroFocus.removeListener(_rebuild);
    _hero.dispose();
    _heroFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onHeroChange() {
    if (!mounted) return;
    setState(() {
      _inputRevision++;
      _importError = null;
      _showRawText = false;
      _provenance = ArtifactProvenance.typed;
    });
  }

  Future<void> _paste({bool reportEmpty = false}) async {
    final int request = ++_importRequest;
    final int revision = _inputRevision;
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || request != _importRequest || revision != _inputRevision) {
      return;
    }
    final String? text = data?.text;
    if (text != null && text.isNotEmpty) {
      _hero.text = text;
      setState(() => _provenance = ArtifactProvenance.clipboard);
    } else if (reportEmpty) {
      setState(() => _importError = 'The clipboard does not contain text.');
    }
  }

  Future<void> _consumeAppIntents() async {
    if (!mounted || _handlingAppIntents) return;
    _handlingAppIntents = true;
    final ShareInboxController inbox = ShareInboxScope.of(context);
    final WorkSessionController sessions = WorkSessionScope.of(context);
    try {
      while (mounted && inbox.intentRequests.isNotEmpty) {
        final AppIntentRequest? request = inbox.takeIntentRequest(
          inbox.intentRequests.first.id,
        );
        if (request == null) continue;
        widget.onAppIntentFocus?.call();
        switch (request.action) {
          case AppIntentAction.inspectClipboard:
            await _paste(reportEmpty: true);
          case AppIntentAction.resumeLastSession:
            if (sessions.recentSessions.isEmpty ||
                !sessions.resume(sessions.recentSessions.first)) {
              if (mounted) {
                setState(
                  () => _importError = 'There is no safe session to resume.',
                );
              }
            }
          case AppIntentAction.runWorkflow:
            final SavedWorkflow? workflow = sessions.savedWorkflows
                .where((SavedWorkflow value) => value.id == request.workflowId)
                .firstOrNull;
            if (workflow == null || request.input == null) {
              if (mounted) {
                setState(
                  () => _importError = 'That saved workflow is unavailable.',
                );
              }
              continue;
            }
            _hero.text = request.input!;
            if (!mounted) return;
            setState(() => _provenance = ArtifactProvenance.typed);
            final int? index = sessions.rerun(workflow, request.input!);
            if (index == null) continue;
            final WorkflowStep step = sessions.session!.steps[index];
            final UtilityDescriptor? tool = UtilityCatalog.byIdOrNull(
              step.toolId,
            );
            if (tool != null && mounted) {
              await ToolDetailRoute.push(
                context,
                tool,
                seed: step.input.rawValue,
                initialArtifact: step.input,
                sessionStepIndex: index,
              );
            }
        }
      }
    } finally {
      _handlingAppIntents = false;
    }
  }

  void _clear() {
    _importRequest++;
    _hero.clear();
    setState(() => _provenance = ArtifactProvenance.typed);
  }

  Future<void> _scan() async {
    final int request = ++_importRequest;
    final int revision = _inputRevision;
    final String? result = await (widget.qrScanner ?? pushQrScanner)(context);
    if (mounted &&
        request == _importRequest &&
        revision == _inputRevision &&
        result != null &&
        result.isNotEmpty) {
      _hero.text = result;
      setState(() => _provenance = ArtifactProvenance.camera);
    }
  }

  Future<void> _import() async {
    final int request = ++_importRequest;
    final int revision = _inputRevision;
    if (_importError != null) setState(() => _importError = null);
    final ExternalInputResult result =
        await (widget.externalInputImporter ?? const ExternalInputImporter())
            .pick();
    if (!mounted || request != _importRequest || revision != _inputRevision) {
      return;
    }
    switch (result) {
      case ExternalInputCancelled():
        return;
      case ExternalInputFailure(:final message):
        setState(() => _importError = message);
      case ExternalInputSuccess(:final artifact):
        _hero.text = artifact.rawValue;
        setState(() => _provenance = artifact.provenance);
    }
  }

  void _open(UtilityDescriptor tool, {Artifact<Object?>? artifact}) {
    final String input = artifact?.rawValue ?? _hero.text;
    final OpenInToolCallback? open = widget.onOpenTool;
    if (open != null) {
      open(tool, input);
    } else {
      final int? stepIndex = artifact == null
          ? null
          : WorkSessionScope.of(context).start(tool, artifact);
      ToolDetailRoute.push(
        context,
        tool,
        seed: input,
        initialArtifact: artifact,
        sessionStepIndex: stepIndex,
      );
    }
  }

  Future<void> _chooseTool() async {
    final UtilityDescriptor? choice =
        await showCupertinoModalPopup<UtilityDescriptor>(
          context: context,
          builder: (BuildContext context) => CupertinoActionSheet(
            title: const Text('Send to tool'),
            actions: <Widget>[
              for (final UtilityDescriptor tool in UtilityCatalog.all)
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(tool),
                  child: Text(tool.name),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        );
    if (mounted && choice != null) _open(choice);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String input = _hero.text.trim();
    final DetectionPreferenceController preferences =
        DetectionPreferenceScope.of(context);
    final List<DetectionMatch<Object?>> detected = preferences.rank(
      UtilityCatalog.detectArtifacts(_hero.text, provenance: _provenance),
    );
    final bool hasShape = detected.isNotEmpty;
    final List<UtilityDescriptor> nameMatches = hasShape
        ? const <UtilityDescriptor>[]
        : UtilityCatalog.searchStable(input);
    final _WorkbenchState state = input.isEmpty
        ? _WorkbenchState.empty
        : hasShape
        ? _WorkbenchState.artifact
        : nameMatches.isNotEmpty
        ? _WorkbenchState.search
        : _WorkbenchState.unknown;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: widget.navigationBar,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg,
            MqSpacing.md,
            MqSpacing.lg,
            MqLayout.tabBarClearance,
          ),
          children: <Widget>[
            CompactPasteBar(
              controller: _hero,
              focusNode: _heroFocus,
              onPaste: _paste,
              onClear: _clear,
              onScan: _scan,
              onImport: widget.importEnabled ? _import : null,
            ),
            if (_importError case final String error) ...<Widget>[
              const SizedBox(height: MqSpacing.sm),
              Semantics(
                liveRegion: true,
                label: error,
                child: MqStatus(label: error, kind: MqStatusKind.warning),
              ),
            ],
            _shareInbox(context),
            _result(context, state, detected, nameMatches),
            _currentSession(context),
            _savedWorkflows(context),
          ],
        ),
      ),
    );
  }

  Widget _shareInbox(BuildContext context) {
    final ShareInboxController inbox = ShareInboxScope.of(context);
    if (inbox.items.isEmpty && inbox.error == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionRule(label: 'Shared inbox'),
        if (inbox.error case final String error)
          Semantics(
            liveRegion: true,
            label: error,
            child: MqStatus(label: error, kind: MqStatusKind.warning),
          ),
        for (final ShareInboxItem item in inbox.items) ...<Widget>[
          MqSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  item.label,
                  style: MqTextStyles.headline.copyWith(
                    color: context.mq.colors.textPri,
                  ),
                ),
                const SizedBox(height: MqSpacing.xs),
                Text(
                  item.artifact.safePreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MqTextStyles.monoMd.copyWith(
                    color: context.mq.colors.monoText,
                  ),
                ),
                const SizedBox(height: MqSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MqButton(
                        label: 'Use in Workbench',
                        size: MqButtonSize.sm,
                        onPressed: _acceptingSharedItems.contains(item.id)
                            ? null
                            : () => _acceptSharedItem(item),
                      ),
                    ),
                    const SizedBox(width: MqSpacing.sm),
                    MqButton(
                      label: 'Dismiss',
                      size: MqButtonSize.sm,
                      variant: MqButtonVariant.glass,
                      onPressed: _acceptingSharedItems.contains(item.id)
                          ? null
                          : () => inbox.remove(item.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: MqSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _acceptSharedItem(ShareInboxItem item) async {
    if (!_acceptingSharedItems.add(item.id)) return;
    setState(() {});
    try {
      await _acceptSharedItemOnce(item);
    } finally {
      _acceptingSharedItems.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _acceptSharedItemOnce(ShareInboxItem item) async {
    final int request = ++_importRequest;
    final int revision = _inputRevision;
    final ShareInboxController inbox = ShareInboxScope.of(context);
    if (!inbox.items.any((ShareInboxItem value) => value.id == item.id)) return;
    if (request != _importRequest || revision != _inputRevision) return;
    final String previousText = _hero.text;
    final ArtifactProvenance previousProvenance = _provenance;
    _hero.text = item.artifact.rawValue;
    setState(() => _provenance = ArtifactProvenance.shareExtension);
    final int appliedRevision = _inputRevision;
    if (await inbox.remove(item.id) || !mounted) return;
    if (request != _importRequest || appliedRevision != _inputRevision) {
      return;
    }
    _hero.text = previousText;
    setState(() => _provenance = previousProvenance);
  }

  Widget _currentSession(BuildContext context) {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final WorkSession? session = sessions.session;
    if (session == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionRule(label: 'Current session'),
          MqEmptyHint(label: 'No current session'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionRule(label: 'Current session'),
        MqSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < session.steps.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: MqSpacing.md),
                _SessionStepRow(
                  index: i,
                  step: session.steps[i],
                  onActions: () => _showStepActions(i),
                ),
              ],
            ],
          ),
        ),
        if (sessions.canSaveCurrent) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          MqButton(
            label: 'Save workflow',
            icon: MqIcons.plus,
            variant: MqButtonVariant.glass,
            onPressed: _saveWorkflow,
            full: true,
          ),
        ],
        if (sessions.branchOrigin case final WorkSession original) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          Semantics(
            label:
                'Original path preserved with ${original.steps.length} steps',
            child: Text(
              'Original path · ${original.steps.length} steps',
              style: MqTextStyles.caption1.copyWith(
                color: context.mq.colors.textSec,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _savedWorkflows(BuildContext context) {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionRule(label: 'Saved workflows'),
        if (sessions.workflowError case final String error) ...<Widget>[
          Semantics(
            liveRegion: true,
            label: error,
            child: MqSurface(
              background: context.mq.colors.warningBg,
              borderColor: context.mq.colors.warning,
              child: Text(
                error,
                style: MqTextStyles.subhead.copyWith(
                  color: context.mq.colors.textPri,
                ),
              ),
            ),
          ),
          const SizedBox(height: MqSpacing.sm),
        ],
        if (sessions.savedWorkflows.isEmpty)
          const MqEmptyHint(label: 'No saved workflows')
        else
          for (final SavedWorkflow workflow
              in sessions.savedWorkflows) ...<Widget>[
            _SavedWorkflowCard(
              workflow: workflow,
              canRun: _hero.text.trim().isNotEmpty,
              onRun: () => _runWorkflow(workflow),
              onRename: () => _renameWorkflow(workflow),
              onDelete: () => _deleteWorkflow(workflow),
            ),
            const SizedBox(height: MqSpacing.sm),
          ],
      ],
    );
  }

  Future<void> _saveWorkflow() async {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final WorkSession? captured = sessions.session;
    if (captured == null) return;
    final TextEditingController name = TextEditingController(
      text: captured.name.replaceFirst(RegExp(r' session$'), ''),
    );
    final String? value = await _nameDialog('Save workflow', name);
    name.dispose();
    if (mounted && value != null && identical(sessions.session, captured)) {
      await sessions.saveCurrent(value);
    }
  }

  Future<void> _renameWorkflow(SavedWorkflow workflow) async {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final TextEditingController name = TextEditingController(
      text: workflow.name,
    );
    final String? value = await _nameDialog('Rename workflow', name);
    name.dispose();
    if (mounted && value != null) {
      await sessions.renameWorkflow(workflow.id, value);
    }
  }

  Future<String?> _nameDialog(String title, TextEditingController controller) =>
      showCupertinoDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: CupertinoTextField(controller: controller, maxLength: 80),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

  Future<void> _deleteWorkflow(SavedWorkflow workflow) async {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete workflow?'),
        content: Text('${workflow.name} will be removed from this device.'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await sessions.deleteWorkflow(workflow.id);
    }
  }

  void _runWorkflow(SavedWorkflow workflow) {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final int? index = sessions.rerun(workflow, _hero.text);
    if (index == null) return;
    final WorkflowStep step = sessions.session!.steps[index];
    final UtilityDescriptor? tool = UtilityCatalog.byIdOrNull(step.toolId);
    if (tool == null) return;
    ToolDetailRoute.push(
      context,
      tool,
      seed: step.input.rawValue,
      initialArtifact: step.input,
      sessionStepIndex: index,
    );
  }

  Future<void> _showStepActions(int index) async {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final WorkSession? session = sessions.session;
    if (session == null || index < 0 || index >= session.steps.length) return;
    final WorkflowStep step = session.steps[index];
    final bool canExport = WorkSessionController.canExport(step);
    final bool canReuse =
        step.toolAvailable &&
        step.status == WorkflowStepStatus.completed &&
        step.output != null;
    final bool hasDownstream = index < session.steps.length - 1;
    final _StepAction? action = await showCupertinoModalPopup<_StepAction>(
      context: context,
      builder: (BuildContext sheetContext) => CupertinoActionSheet(
        title: Text('Step ${index + 1} actions'),
        actions: <Widget>[
          if (step.toolAvailable)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.reopen),
              child: const Text('Reopen'),
            ),
          if (canExport) ...<Widget>[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(_StepAction.copy),
              child: const Text('Copy output'),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.share),
              child: const Text('Share output'),
            ),
          ],
          if (step.toolAvailable)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.replace),
              child: const Text('Replace input'),
            ),
          if (hasDownstream)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.removeSubsequent),
              child: const Text('Remove subsequent steps'),
            ),
          if (canReuse)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.duplicate),
              child: const Text('Duplicate step'),
            ),
          if (canReuse && sessions.branchOrigin == null)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_StepAction.branch),
              child: const Text('Branch from here'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || action == null || !identical(sessions.session, session)) {
      return;
    }
    switch (action) {
      case _StepAction.reopen:
        _reopenStep(index);
      case _StepAction.copy:
        CopyToClipboardUtil.copyToClipboard(context, step.output!.rawValue);
      case _StepAction.share:
        await _shareOutput(step);
      case _StepAction.replace:
        await _replaceStepInput(index);
      case _StepAction.removeSubsequent:
        sessions.removeSubsequent(index);
      case _StepAction.duplicate:
        sessions.duplicate(index);
      case _StepAction.branch:
        sessions.branchFrom(index);
    }
  }

  void _reopenStep(int index) {
    final WorkSession? session = WorkSessionScope.of(context).session;
    if (session == null || index < 0 || index >= session.steps.length) return;
    final WorkflowStep step = session.steps[index];
    final UtilityDescriptor? tool = UtilityCatalog.byIdOrNull(step.toolId);
    if (tool == null) return;
    ToolDetailRoute.push(
      context,
      tool,
      seed: step.input.rawValue,
      initialArtifact: step.input,
      sessionStepIndex: index,
    );
  }

  Future<void> _replaceStepInput(int index) async {
    final WorkSessionController sessions = WorkSessionScope.of(context);
    final WorkSession? session = sessions.session;
    if (session == null || index < 0 || index >= session.steps.length) return;
    final bool removesLaterSteps = index < session.steps.length - 1;
    final TextEditingController input = TextEditingController(
      text: session.steps[index].input.rawValue,
    );
    final String? replacement = await showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text(
          removesLaterSteps
              ? 'Replace input and remove later steps?'
              : 'Replace input?',
        ),
        content: Column(
          children: <Widget>[
            if (removesLaterSteps)
              const Padding(
                padding: EdgeInsets.only(bottom: MqSpacing.sm),
                child: Text('All steps after this one will be removed.'),
              ),
            CupertinoTextField(controller: input, minLines: 1, maxLines: 4),
          ],
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: removesLaterSteps,
            onPressed: () => Navigator.of(dialogContext).pop(input.text),
            child: Text(removesLaterSteps ? 'Replace and remove' : 'Replace'),
          ),
        ],
      ),
    );
    input.dispose();
    if (mounted &&
        replacement != null &&
        identical(sessions.session, session)) {
      sessions.replaceInput(index, replacement);
    }
  }

  Future<void> _shareOutput(WorkflowStep step) async {
    if (!WorkSessionController.canExport(step)) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: step.output!.rawValue,
          subject:
              '${UtilityCatalog.byIdOrNull(step.toolId)?.name ?? step.toolId} output',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      // Native share surfaces are best-effort; the user can retry.
    }
  }

  Widget _result(
    BuildContext context,
    _WorkbenchState state,
    List<DetectionMatch<Object?>> detected,
    List<UtilityDescriptor> nameMatches,
  ) {
    final c = context.mq.colors;
    final DetectionPreferenceController preferences =
        DetectionPreferenceScope.of(context);
    if (state == _WorkbenchState.empty) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Empty Workbench',
        child: const MqEmptyHint(
          label: 'Capture something to begin',
          detail: 'Type, paste, or scan a QR code.',
        ),
      );
    }

    if (state == _WorkbenchState.unknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionRule(label: 'Result'),
          Semantics(
            container: true,
            liveRegion: true,
            label: 'Unknown text. Open as text or send to a tool.',
            child: MqSurface(
              background: c.warningBg,
              borderColor: c.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Unknown text',
                    style: MqTextStyles.headline.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MqSpacing.xs),
                  Text(
                    'No tool matched this value.',
                    style: MqTextStyles.body.copyWith(color: c.textSec),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqButton(
                    label: 'Open as text',
                    variant: MqButtonVariant.glass,
                    onPressed: () => setState(() => _showRawText = true),
                    full: true,
                  ),
                  const SizedBox(height: MqSpacing.sm),
                  MqButton(
                    label: 'Send to tool',
                    variant: MqButtonVariant.tinted,
                    onPressed: _chooseTool,
                    full: true,
                  ),
                ],
              ),
            ),
          ),
          if (_showRawText) ...<Widget>[
            const SectionRule(label: 'Text'),
            Semantics(
              container: true,
              label: 'Opened text: ${_hero.text}',
              child: MqSurface(
                child: Text(
                  _hero.text,
                  style: MqTextStyles.monoMd.copyWith(color: c.monoText),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final bool artifact = state == _WorkbenchState.artifact;
    final String title = artifact ? 'Artifact detected' : 'Tool search';
    final List<_DetectedSuggestion> ranked = artifact
        ? _rankedSuggestions(detected)
        : const <_DetectedSuggestion>[];
    final int suggestionCount = artifact ? ranked.length : nameMatches.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionRule(label: 'Tool suggestions'),
        Semantics(
          container: true,
          liveRegion: true,
          label: artifact
              ? '$title. ${ranked.first.match.reason} $suggestionCount suggestions.'
              : '$title. $suggestionCount suggestions.',
          child: MqSurface(
            background: artifact ? c.successBg : c.accentBg,
            borderColor: artifact ? c.success : c.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: MqTextStyles.headline.copyWith(color: c.textPri),
                ),
                const SizedBox(height: MqSpacing.sm),
                if (artifact)
                  for (final _DetectedSuggestion suggestion in ranked)
                    _SuggestionRow(
                      tool: suggestion.tool,
                      detail:
                          '${suggestion.primary ? 'Primary' : 'Alternative'} · ${(suggestion.match.confidence * 100).round()}% · ${suggestion.match.reason}',
                      onTap: () => _open(
                        suggestion.tool,
                        artifact: suggestion.match.artifact,
                      ),
                      onMakePrimary:
                          suggestion.primary || !preferences.canPrefer(detected)
                          ? null
                          : () => preferences.prefer(
                              detected,
                              suggestion.match.artifact.kind,
                            ),
                    )
                else
                  for (final UtilityDescriptor tool in nameMatches)
                    _SuggestionRow(tool: tool, onTap: () => _open(tool)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_DetectedSuggestion> _rankedSuggestions(
    List<DetectionMatch<Object?>> matches,
  ) {
    final Set<String> seen = <String>{};
    final List<_DetectedSuggestion> suggestions = <_DetectedSuggestion>[];
    for (final DetectionMatch<Object?> match in matches) {
      for (final UtilityDescriptor tool in UtilityCatalog.toolsFor(match)) {
        if (!seen.add(tool.id)) continue;
        suggestions.add((
          match: match,
          tool: tool,
          primary: suggestions.isEmpty,
        ));
      }
    }
    return suggestions;
  }
}

class _SavedWorkflowCard extends StatelessWidget {
  const _SavedWorkflowCard({
    required this.workflow,
    required this.canRun,
    required this.onRun,
    required this.onRename,
    required this.onDelete,
  });

  final SavedWorkflow workflow;
  final bool canRun;
  final VoidCallback onRun;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String sequence = workflow.steps
        .map(
          (SavedWorkflowStep step) =>
              UtilityCatalog.byIdOrNull(step.toolId)?.name ??
              '${step.toolId} (unavailable)',
        )
        .join(' → ');
    return MqSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            workflow.name,
            style: MqTextStyles.headline.copyWith(color: c.textPri),
          ),
          const SizedBox(height: MqSpacing.xs),
          Text(
            sequence,
            style: MqTextStyles.caption1.copyWith(color: c.textSec),
          ),
          const SizedBox(height: MqSpacing.sm),
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xs,
            children: <Widget>[
              MqButton(
                label: 'Run',
                size: MqButtonSize.sm,
                onPressed: canRun ? onRun : null,
              ),
              MqButton(
                label: 'Rename',
                size: MqButtonSize.sm,
                variant: MqButtonVariant.glass,
                onPressed: onRename,
              ),
              MqButton(
                label: 'Delete',
                size: MqButtonSize.sm,
                variant: MqButtonVariant.plain,
                destructive: true,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionStepRow extends StatelessWidget {
  const _SessionStepRow({
    required this.index,
    required this.step,
    required this.onActions,
  });

  final int index;
  final WorkflowStep step;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final UtilityDescriptor? tool = UtilityCatalog.byIdOrNull(step.toolId);
    final String name = tool?.name ?? 'Unavailable tool';
    final String status = switch (step.status) {
      WorkflowStepStatus.pending => 'Pending',
      WorkflowStepStatus.running => 'Running',
      WorkflowStepStatus.completed => 'Completed',
      WorkflowStepStatus.failed => 'Failed',
    };
    final String input = step.input.safePreview;
    final String? output = step.output?.safePreview;
    return Semantics(
      container: true,
      button: true,
      onTap: onActions,
      label:
          'Step ${index + 1}, $name, $status. Input $input.${output == null ? '' : ' Output $output.'} Actions available.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onActions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${index + 1}. $name',
                    style: MqTextStyles.headline.copyWith(color: c.textPri),
                  ),
                ),
                MqStatus(
                  label: status,
                  kind: switch (step.status) {
                    WorkflowStepStatus.completed => MqStatusKind.success,
                    WorkflowStepStatus.failed => MqStatusKind.danger,
                    WorkflowStepStatus.running => MqStatusKind.info,
                    WorkflowStepStatus.pending => MqStatusKind.neutral,
                  },
                ),
              ],
            ),
            const SizedBox(height: MqSpacing.xs),
            Text(
              'Input · $input',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MqTextStyles.monoSm.copyWith(color: c.monoText),
            ),
            if (output != null)
              Text(
                'Output · $output',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MqTextStyles.monoSm.copyWith(color: c.monoText),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.tool,
    required this.onTap,
    this.detail,
    this.onMakePrimary,
  });

  final UtilityDescriptor tool;
  final VoidCallback onTap;
  final String? detail;
  final VoidCallback? onMakePrimary;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: detail == null
              ? 'Open ${tool.name}'
              : 'Open ${tool.name}. $detail',
          button: true,
          excludeSemantics: true,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
            minimumSize: const Size.fromHeight(44),
            onPressed: onTap,
            child: Row(
              children: <Widget>[
                Icon(tool.icon, size: 18, color: tool.tint),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tool.name,
                        style: MqTextStyles.body.copyWith(color: c.textPri),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MqTextStyles.caption1.copyWith(
                            color: c.textSec,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(MqIcons.chevR, size: 16, color: c.textTer),
              ],
            ),
          ),
        ),
        if (onMakePrimary != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MqButton(
              label: 'Make primary',
              semanticsLabel: 'Make ${tool.name} the primary interpretation',
              size: MqButtonSize.sm,
              variant: MqButtonVariant.glass,
              onPressed: onMakePrimary,
            ),
          ),
      ],
    );
  }
}
