import 'package:flutter/widgets.dart';

import '../models/artifact.dart';
import '../models/work_session.dart';
import '../utility_catalog.dart';
import '../utils/sensitive_data_policy.dart';

/// The active mobile workflow. Persistence and editing belong to later phases.
class WorkSessionController extends ChangeNotifier {
  WorkSession? _session;
  WorkSession? _branchOrigin;

  WorkSession? get session => _session;
  WorkSession? get branchOrigin => _branchOrigin;

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

  int start(UtilityDescriptor tool, Artifact<Object?> input) {
    final DateTime now = DateTime.now();
    _branchOrigin = null;
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
    return 0;
  }

  /// Completes [stepIndex] and appends its compatible destination atomically.
  /// A stale route cannot overwrite or branch an existing sequence.
  int? addNext(int stepIndex, UtilityDescriptor target, String output) {
    final WorkSession? current = _session;
    if (current == null || !isCurrent(stepIndex) || output.isEmpty) return null;
    final WorkflowStep sourceStep = current.steps[stepIndex];
    final List<UtilityDescriptor> compatible =
        UtilityCatalog.compatibleNextSteps(sourceStep.toolId, output);
    if (!compatible.any((UtilityDescriptor tool) => tool.id == target.id)) {
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
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.running,
        ),
      ],
    );
    notifyListeners();
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
    final DateTime now = DateTime.now();
    _session = WorkSession(
      id: '${current.id}-branch',
      name: '${current.name} branch',
      createdAt: now,
      updatedAt: now,
      steps: current.steps.take(stepIndex + 1).map(_copyStep).toList(),
    );
    notifyListeners();
    return true;
  }

  void clear() {
    if (_session == null && _branchOrigin == null) return;
    _session = null;
    _branchOrigin = null;
    notifyListeners();
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
