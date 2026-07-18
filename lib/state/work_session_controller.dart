import 'package:flutter/widgets.dart';

import '../models/artifact.dart';
import '../models/work_session.dart';
import '../utility_catalog.dart';

/// The active mobile workflow. Persistence and editing belong to later phases.
class WorkSessionController extends ChangeNotifier {
  WorkSession? _session;

  WorkSession? get session => _session;

  bool isCurrent(int stepIndex) =>
      _session != null && stepIndex == _session!.steps.length - 1;

  int start(UtilityDescriptor tool, Artifact<Object?> input) {
    final DateTime now = DateTime.now();
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

  void clear() {
    if (_session == null) return;
    _session = null;
    notifyListeners();
  }

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
