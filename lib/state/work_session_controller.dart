import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artifact.dart';
import '../models/saved_workflow.dart';
import '../models/work_session.dart';
import '../utility_catalog.dart';
import '../utils/sensitive_data_policy.dart';

/// The active mobile workflow. Persistence and editing belong to later phases.
class WorkSessionController extends ChangeNotifier {
  WorkSessionController({
    Iterable<SavedWorkflow> savedWorkflows = const <SavedWorkflow>[],
    Iterable<WorkSession> recentSessions = const <WorkSession>[],
    SharedPreferences? prefs,
  }) : _savedWorkflows = savedWorkflows.toList(),
       _recentSessions = recentSessions.toList(),
       _prefs = prefs {
    if (_savedWorkflows.map((SavedWorkflow value) => value.id).toSet().length !=
            _savedWorkflows.length ||
        _recentSessions.map((WorkSession value) => value.id).toSet().length !=
            _recentSessions.length) {
      throw ArgumentError('Work session IDs must be unique.');
    }
  }

  static const String storageKey = 'mb.work_sessions';
  static const int _schemaVersion = 1;
  static const int _maxRecent = 10;

  WorkSession? _session;
  WorkSession? _branchOrigin;
  final List<SavedWorkflow> _savedWorkflows;
  final List<WorkSession> _recentSessions;
  final SharedPreferences? _prefs;
  Future<void> _writes = Future<void>.value();
  SavedWorkflow? _rerunning;
  String? _workflowError;

  WorkSession? get session => _session;
  WorkSession? get branchOrigin => _branchOrigin;
  List<SavedWorkflow> get savedWorkflows =>
      List<SavedWorkflow>.unmodifiable(_savedWorkflows);
  List<WorkSession> get recentSessions =>
      List<WorkSession>.unmodifiable(_recentSessions);
  String? get workflowError => _workflowError;

  static Future<WorkSessionController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null) return WorkSessionController(prefs: prefs);
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['savedWorkflows'] is! List<dynamic> ||
          decoded['recentSessions'] is! List<dynamic>) {
        throw const FormatException('Invalid work session schema.');
      }
      final List<SavedWorkflow> workflows = <SavedWorkflow>[];
      final Set<String> ids = <String>{};
      for (final Object? value in decoded['savedWorkflows'] as List<dynamic>) {
        final SavedWorkflow? workflow = SavedWorkflow.tryFromJson(
          value,
          isKnownTool: (String id) => UtilityCatalog.byIdOrNull(id) != null,
        );
        if (workflow == null) throw const FormatException('Invalid workflow.');
        if (!ids.add(workflow.id)) {
          throw const FormatException('Duplicate workflow ID.');
        }
        workflows.add(workflow);
      }
      final List<WorkSession> recent = <WorkSession>[];
      final Set<String> recentIds = <String>{};
      for (final Object? value in decoded['recentSessions'] as List<dynamic>) {
        final WorkSession? restored = WorkSession.tryFromJson(
          value,
          isKnownTool: (String id) => UtilityCatalog.byIdOrNull(id) != null,
        );
        if (restored == null) {
          throw const FormatException('Invalid recent session.');
        }
        if (!_resumable(restored)) continue;
        if (!recentIds.add(restored.id)) {
          throw const FormatException('Duplicate recent session ID.');
        }
        recent.add(restored);
      }
      return WorkSessionController(
        savedWorkflows: workflows,
        recentSessions: recent.take(_maxRecent),
        prefs: prefs,
      );
    } catch (_) {
      await prefs.remove(storageKey);
      return WorkSessionController(prefs: prefs);
    }
  }

  bool isCurrent(int stepIndex) =>
      _session != null && stepIndex == _session!.steps.length - 1;

  static bool canExport(WorkflowStep step) {
    final Artifact<Object?>? output = step.output;
    return output != null &&
        !step.input.isSensitive &&
        !output.isSensitive &&
        !SensitiveDataPolicy.protects(
          utilityId: step.toolId,
          values: <String>[output.rawValue],
        );
  }

  bool get canSaveCurrent =>
      _session?.steps.any(
        (WorkflowStep step) => step.status == WorkflowStepStatus.completed,
      ) ??
      false;

  Future<SavedWorkflow?> saveCurrent(String name) async {
    final WorkSession? current = _session;
    final String trimmed = name.trim();
    if (current == null ||
        !canSaveCurrent ||
        trimmed.isEmpty ||
        isProtectedWorkflowString(trimmed)) {
      _setError('Choose a safe name for this completed workflow.');
      return null;
    }
    final DateTime now = DateTime.now();
    final SavedWorkflow workflow = SavedWorkflow(
      id: 'workflow-${now.microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: now,
      updatedAt: now,
      steps: <SavedWorkflowStep>[
        for (final WorkflowStep step in current.steps)
          SavedWorkflowStep(toolId: step.toolId, settings: step.settings),
      ],
    );
    _savedWorkflows.insert(0, workflow);
    _workflowError = null;
    notifyListeners();
    await _persist();
    return workflow;
  }

  Future<bool> renameWorkflow(String id, String name) async {
    final int index = _savedWorkflows.indexWhere(
      (SavedWorkflow workflow) => workflow.id == id,
    );
    final String trimmed = name.trim();
    if (index < 0 || trimmed.isEmpty || isProtectedWorkflowString(trimmed)) {
      _setError('Choose a safe workflow name.');
      return false;
    }
    _savedWorkflows[index] = _savedWorkflows[index].rename(trimmed);
    _workflowError = null;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> deleteWorkflow(String id) async {
    final int before = _savedWorkflows.length;
    _savedWorkflows.removeWhere((SavedWorkflow workflow) => workflow.id == id);
    if (_savedWorkflows.length == before) return false;
    if (_rerunning?.id == id) _rerunning = null;
    _workflowError = null;
    notifyListeners();
    await _persist();
    return true;
  }

  int? rerun(SavedWorkflow workflow, String input) {
    final SavedWorkflow? saved = _savedWorkflows
        .where((SavedWorkflow candidate) => candidate.id == workflow.id)
        .firstOrNull;
    if (saved == null) {
      _setError('This workflow is no longer saved.');
      return null;
    }
    final SavedWorkflowStep? unavailable = saved.steps
        .where((SavedWorkflowStep step) => !step.available)
        .firstOrNull;
    if (unavailable != null) {
      _setError('${unavailable.toolId} is no longer available.');
      return null;
    }
    final UtilityDescriptor first = UtilityCatalog.byId(
      saved.steps.first.toolId,
    );
    final DetectionMatch<Object?>? match =
        UtilityCatalog.detectArtifacts(
              input,
              provenance: ArtifactProvenance.typed,
            )
            .where(
              (DetectionMatch<Object?> candidate) =>
                  candidate.compatibleToolIds.contains(first.id),
            )
            .firstOrNull;
    if (match == null) {
      _setError('Input is not compatible with ${first.name}.');
      return null;
    }
    final DateTime now = DateTime.now();
    _branchOrigin = null;
    _rerunning = saved;
    _workflowError = null;
    _session = WorkSession(
      id: 'session-${now.microsecondsSinceEpoch}',
      name: '${saved.name} run',
      createdAt: now,
      updatedAt: now,
      steps: <WorkflowStep>[
        WorkflowStep(
          toolId: first.id,
          input: _protect(first, match.artifact),
          settings: saved.steps.first.settings,
          status: WorkflowStepStatus.running,
        ),
      ],
    );
    notifyListeners();
    _rememberCurrent();
    return 0;
  }

  bool resume(WorkSession recent) {
    final WorkSession? saved = _recentSessions
        .where((WorkSession session) => session.id == recent.id)
        .firstOrNull;
    if (saved == null || !_resumable(saved)) {
      _setError('This session can no longer be resumed.');
      return false;
    }
    _session = saved;
    _branchOrigin = null;
    _rerunning = null;
    _workflowError = null;
    notifyListeners();
    return true;
  }

  int start(UtilityDescriptor tool, Artifact<Object?> input) {
    final DateTime now = DateTime.now();
    _branchOrigin = null;
    _rerunning = null;
    _workflowError = null;
    _session = WorkSession(
      id: 'session-${now.microsecondsSinceEpoch}',
      name: '${tool.name} session',
      createdAt: now,
      updatedAt: now,
      steps: <WorkflowStep>[
        WorkflowStep(
          toolId: tool.id,
          input: _protect(tool, input),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.running,
        ),
      ],
    );
    notifyListeners();
    _rememberCurrent();
    return 0;
  }

  /// Completes [stepIndex] and appends its compatible destination atomically.
  /// A stale route cannot overwrite or branch an existing sequence.
  int? addNext(int stepIndex, UtilityDescriptor target, String output) {
    final WorkSession? current = _session;
    if (current == null || !isCurrent(stepIndex) || output.isEmpty) return null;
    final WorkflowStep sourceStep = current.steps[stepIndex];
    final SavedWorkflowStep? expected =
        _rerunning != null && stepIndex + 1 < _rerunning!.steps.length
        ? _rerunning!.steps[stepIndex + 1]
        : null;
    if (expected != null && target.id != expected.toolId) {
      _setError(
        'Next saved step is ${UtilityCatalog.byIdOrNull(expected.toolId)?.name ?? expected.toolId}.',
      );
      return null;
    }
    final List<UtilityDescriptor> compatible =
        UtilityCatalog.compatibleNextSteps(sourceStep.toolId, output);
    if (!compatible.any((UtilityDescriptor tool) => tool.id == target.id)) {
      if (expected != null) {
        _setError('Output is not compatible with ${target.name}.');
      }
      return null;
    }

    final DetectionMatch<Object?> match =
        UtilityCatalog.detectArtifacts(
          output,
          provenance: ArtifactProvenance.generated,
        ).firstWhere(
          (DetectionMatch<Object?> match) =>
              match.compatibleToolIds.contains(target.id),
        );
    final UtilityDescriptor source = UtilityCatalog.byId(sourceStep.toolId);
    final Artifact<Object?> snapshot = _protect(
      source,
      match.artifact,
      forceSensitive: sourceStep.input.isSensitive,
    );
    final Artifact<Object?> nextInput = _protect(target, snapshot);
    final DateTime now = DateTime.now();
    _session = WorkSession(
      id: current.id,
      name: current.name,
      createdAt: current.createdAt,
      updatedAt: now,
      steps: <WorkflowStep>[
        ...current.steps.take(stepIndex),
        WorkflowStep(
          toolId: sourceStep.toolId,
          input: sourceStep.input,
          settings: sourceStep.settings,
          output: snapshot,
          status: WorkflowStepStatus.completed,
          toolAvailable: sourceStep.toolAvailable,
        ),
        WorkflowStep(
          toolId: target.id,
          input: nextInput,
          settings: expected?.settings ?? const <String, Object?>{},
          status: WorkflowStepStatus.running,
        ),
      ],
    );
    _workflowError = null;
    if (_rerunning != null && stepIndex + 1 >= _rerunning!.steps.length - 1) {
      _rerunning = null;
    }
    notifyListeners();
    _rememberCurrent();
    return stepIndex + 1;
  }

  bool replaceInput(int stepIndex, String input) {
    final WorkSession? current = _session;
    if (current == null || !_contains(current, stepIndex)) return false;
    final WorkflowStep step = current.steps[stepIndex];
    final UtilityDescriptor? tool = UtilityCatalog.byIdOrNull(step.toolId);
    if (!step.toolAvailable || tool == null) return false;
    final List<DetectionMatch<Object?>> matches =
        UtilityCatalog.detectArtifacts(
          input,
          provenance: ArtifactProvenance.typed,
        );
    final DetectionMatch<Object?>? match = matches
        .where(
          (DetectionMatch<Object?> candidate) =>
              candidate.compatibleToolIds.contains(tool.id),
        )
        .firstOrNull;
    final Artifact<Object?> replacement = _protect(
      tool,
      match?.artifact ??
          Artifact<Object?>(
            kind: step.input.kind,
            rawValue: input,
            provenance: ArtifactProvenance.typed,
          ),
      forceSensitive: step.input.isSensitive,
    );
    _replace(current, <WorkflowStep>[
      ...current.steps.take(stepIndex),
      WorkflowStep(
        toolId: step.toolId,
        input: replacement,
        settings: step.settings,
        status: WorkflowStepStatus.running,
        toolAvailable: step.toolAvailable,
      ),
    ]);
    _rerunning = null;
    return true;
  }

  bool updateSettings(
    int stepIndex,
    WorkSession sessionLease,
    Map<String, Object?> settings,
  ) {
    final WorkSession? current = _session;
    if (current == null ||
        !identical(current, sessionLease) ||
        !isCurrent(stepIndex)) {
      return false;
    }
    final WorkflowStep step = current.steps[stepIndex];
    final Map<String, Object?> safe = sanitizeWorkflowSettings(settings);
    if (jsonEncode(step.settings) == jsonEncode(safe)) return true;
    _replace(current, <WorkflowStep>[
      ...current.steps.take(stepIndex),
      WorkflowStep(
        toolId: step.toolId,
        input: step.input,
        settings: safe,
        output: step.output,
        status: step.status,
        toolAvailable: step.toolAvailable,
      ),
    ]);
    return true;
  }

  bool removeSubsequent(int stepIndex) {
    final WorkSession? current = _session;
    if (current == null || !_contains(current, stepIndex)) return false;
    if (stepIndex == current.steps.length - 1) return false;
    _replace(
      current,
      current.steps.take(stepIndex + 1).map(_copyStep).toList(),
    );
    _rerunning = null;
    return true;
  }

  bool duplicate(int stepIndex) {
    final WorkSession? current = _session;
    if (current == null || !_contains(current, stepIndex)) return false;
    final WorkflowStep source = current.steps[stepIndex];
    if (!source.toolAvailable ||
        source.status != WorkflowStepStatus.completed ||
        source.output == null) {
      return false;
    }
    _replace(current, <WorkflowStep>[
      ...current.steps.take(stepIndex + 1),
      _copyStep(source),
      ...current.steps.skip(stepIndex + 1),
    ]);
    _rerunning = null;
    return true;
  }

  /// Starts one alternate linear path while retaining the exact source path.
  /// Saved/nested branch management belongs to the saved-workflow feature.
  bool branchFrom(int stepIndex) {
    final WorkSession? current = _session;
    if (current == null ||
        _branchOrigin != null ||
        !_contains(current, stepIndex)) {
      return false;
    }
    final WorkflowStep source = current.steps[stepIndex];
    if (!source.toolAvailable ||
        source.status != WorkflowStepStatus.completed ||
        source.output == null) {
      return false;
    }
    _branchOrigin = current;
    _rerunning = null;
    final DateTime now = DateTime.now();
    _session = WorkSession(
      id: '${current.id}-branch',
      name: '${current.name} branch',
      createdAt: now,
      updatedAt: now,
      steps: current.steps.take(stepIndex + 1).map(_copyStep).toList(),
    );
    notifyListeners();
    _rememberCurrent();
    return true;
  }

  Future<void> clear() async {
    if (_session == null && _branchOrigin == null && _recentSessions.isEmpty) {
      return;
    }
    _session = null;
    _branchOrigin = null;
    _recentSessions.clear();
    _rerunning = null;
    _workflowError = null;
    notifyListeners();
    await _persist();
  }

  Future<void> clearRecentSessions() async {
    if (_recentSessions.isEmpty) return;
    _recentSessions.clear();
    notifyListeners();
    await _persist();
  }

  bool _contains(WorkSession session, int index) =>
      index >= 0 && index < session.steps.length;

  void _replace(WorkSession current, List<WorkflowStep> steps) {
    _session = WorkSession(
      id: current.id,
      name: current.name,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      steps: steps,
    );
    _workflowError = null;
    notifyListeners();
    _rememberCurrent();
  }

  void _rememberCurrent() {
    final WorkSession? current = _session;
    if (current == null || !_resumable(current)) return;
    final Map<String, Object?> encoded = current.toJson(
      canPersistTool: (String id) =>
          UtilityCatalog.byIdOrNull(id)?.historyPolicy == HistoryPolicy.enabled,
    );
    if (jsonEncode(encoded).contains('"redacted":true')) return;
    final WorkSession? safe = WorkSession.tryFromJson(
      jsonDecode(jsonEncode(encoded)),
      isKnownTool: (String id) => UtilityCatalog.byIdOrNull(id) != null,
    );
    if (safe == null || !_resumable(safe)) return;
    _recentSessions.removeWhere((WorkSession recent) => recent.id == safe.id);
    _recentSessions.insert(0, safe);
    if (_recentSessions.length > _maxRecent) {
      _recentSessions.removeRange(_maxRecent, _recentSessions.length);
    }
    unawaited(_persist());
  }

  static bool _resumable(WorkSession session) =>
      session.steps.isNotEmpty &&
      session.steps.every(
        (WorkflowStep step) =>
            step.toolAvailable &&
            !step.input.isSensitive &&
            !isProtectedWorkflowString(step.input.rawValue) &&
            !(step.output?.isSensitive ?? false) &&
            (step.output == null ||
                !isProtectedWorkflowString(step.output!.rawValue)),
      );

  Future<void> _persist() {
    if (_prefs == null) return Future<void>.value();
    final String snapshot = jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'savedWorkflows': _savedWorkflows
          .map((SavedWorkflow workflow) => workflow.toJson())
          .toList(),
      'recentSessions': _recentSessions
          .map(
            (WorkSession session) => session.toJson(
              canPersistTool: (String id) =>
                  UtilityCatalog.byIdOrNull(id)?.historyPolicy ==
                  HistoryPolicy.enabled,
            ),
          )
          .toList(),
    });
    final Future<void> next = _writes.then((_) async {
      await _prefs.setString(storageKey, snapshot);
    });
    _writes = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  Future<void> flush() => _writes;

  void _setError(String message) {
    _workflowError = message;
    notifyListeners();
  }

  WorkflowStep _copyStep(WorkflowStep step) => WorkflowStep(
    toolId: step.toolId,
    input: _copyArtifact(step.input),
    settings: step.settings,
    output: step.output == null ? null : _copyArtifact(step.output!),
    status: step.status,
    toolAvailable: step.toolAvailable,
  );

  // parserResult is an ephemeral, potentially mutable cache. Like persisted
  // session snapshots, edited paths rebuild it in the destination tool.
  Artifact<Object?> _copyArtifact(Artifact<Object?> artifact) =>
      Artifact<Object?>(
        kind: artifact.kind,
        rawValue: artifact.rawValue,
        provenance: artifact.provenance,
        sensitivity: artifact.sensitivity,
      );

  Artifact<Object?> _protect(
    UtilityDescriptor tool,
    Artifact<Object?> artifact, {
    bool forceSensitive = false,
  }) => Artifact<Object?>(
    kind: artifact.kind,
    rawValue: artifact.rawValue,
    provenance: artifact.provenance,
    parserResult: artifact.parserResult,
    sensitivity:
        forceSensitive ||
            tool.sensitivity == UtilitySensitivity.sensitive ||
            artifact.isSensitive
        ? ArtifactSensitivity.sensitive
        : ArtifactSensitivity.standard,
  );
}

class WorkSessionScope extends InheritedNotifier<WorkSessionController> {
  const WorkSessionScope({
    super.key,
    required WorkSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static WorkSessionController of(BuildContext context) {
    final WorkSessionScope? scope = context
        .dependOnInheritedWidgetOfExactType<WorkSessionScope>();
    assert(scope != null, 'WorkSessionScope not found.');
    return scope!.notifier!;
  }

  static WorkSessionController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkSessionScope>()?.notifier;
}
