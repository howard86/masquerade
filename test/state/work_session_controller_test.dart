import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';

Artifact<Object?> artifact(
  ArtifactKind kind,
  String raw, {
  ArtifactSensitivity sensitivity = ArtifactSensitivity.standard,
}) => Artifact<Object?>(
  kind: kind,
  rawValue: raw,
  provenance: ArtifactProvenance.typed,
  sensitivity: sensitivity,
);

void main() {
  test('appends an ordered typed snapshot exactly once', () {
    final WorkSessionController controller = WorkSessionController();
    final int first = controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );

    final int? second = controller.addNext(
      first,
      UtilityCatalog.byId('number_base'),
      '1700000000',
    );

    expect(second, 1);
    expect(controller.session!.steps, hasLength(2));
    expect(
      controller.session!.steps.first.status,
      WorkflowStepStatus.completed,
    );
    expect(controller.session!.steps.first.output!.rawValue, '1700000000');
    expect(controller.session!.steps.first.output!.kind, ArtifactKind.number);
    expect(controller.session!.steps.last.input.rawValue, '1700000000');
    expect(controller.session!.steps.last.input.kind, ArtifactKind.number);

    final WorkSession beforeStaleEdit = controller.session!;
    expect(
      controller.addNext(first, UtilityCatalog.byId('timestamp'), '1800000000'),
      isNull,
    );
    expect(controller.session, same(beforeStaleEdit));
    expect(controller.session!.steps.last.input.rawValue, '1700000000');
  });

  test('resolves ambiguous output for the chosen compatible target', () {
    final WorkSessionController timestamp = WorkSessionController();
    timestamp.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    timestamp.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    expect(timestamp.session!.steps.last.input.kind, ArtifactKind.timestamp);

    final WorkSessionController number = WorkSessionController();
    number.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    number.addNext(0, UtilityCatalog.byId('number_base'), '1700000000');
    expect(number.session!.steps.last.input.kind, ArtifactKind.number);
  });

  test('incompatible target fails without mutation or notification', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    final WorkSession before = controller.session!;
    int notifications = 0;
    controller.addListener(() => notifications++);

    expect(
      controller.addNext(0, UtilityCatalog.byId('json'), '1700000000'),
      isNull,
    );
    expect(controller.session, same(before));
    expect(notifications, 0);
  });

  test('represents a synthetic JWT to JSON to Timestamp session safely', () {
    const String rawJwt = 'eyJhbGciOiJub25lIn0.eyJhdCI6MTcwMDAwMDAwMH0.';
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('jwt'),
      artifact(ArtifactKind.jwt, rawJwt),
    );
    expect(
      controller.addNext(0, UtilityCatalog.byId('json'), '{"at":1700000000}'),
      1,
    );
    expect(
      controller.addNext(1, UtilityCatalog.byId('timestamp'), '1700000000'),
      2,
    );

    expect(
      controller.session!.steps.map((WorkflowStep step) => step.toolId),
      <String>['jwt', 'json', 'timestamp'],
    );
    for (final WorkflowStep step in controller.session!.steps) {
      expect(step.input.isSensitive, isTrue);
      expect(step.input.safePreview, isNot(step.input.rawValue));
      if (step.output case final Artifact<Object?> output) {
        expect(output.isSensitive, isTrue);
        expect(output.safePreview, isNot(output.rawValue));
      }
    }
  });

  test('replace resets the step and deterministically removes its tail', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');

    expect(controller.replaceInput(0, '50 bps'), isTrue);

    expect(controller.session!.steps, hasLength(1));
    final WorkflowStep step = controller.session!.steps.single;
    expect(step.input.rawValue, '50 bps');
    expect(step.output, isNull);
    expect(step.status, WorkflowStepStatus.running);
  });

  test('remove subsequent retains an exact selected step', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    final WorkflowStep selected = controller.session!.steps.first;

    expect(controller.removeSubsequent(0), isTrue);

    expect(controller.session!.steps, hasLength(1));
    expect(controller.session!.steps.single.toolId, selected.toolId);
    expect(
      controller.session!.steps.single.output!.rawValue,
      selected.output!.rawValue,
    );
    expect(controller.removeSubsequent(0), isFalse);
  });

  test('duplicate clones a completed step without a second running step', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    expect(controller.duplicate(0), isFalse);
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    final WorkflowStep original = controller.session!.steps.first;

    expect(controller.duplicate(0), isTrue);

    final List<WorkflowStep> steps = controller.session!.steps;
    expect(steps, hasLength(3));
    final WorkflowStep duplicate = steps[1];
    expect(duplicate, isNot(same(original)));
    expect(duplicate.input, isNot(same(original.input)));
    expect(duplicate.settings, isNot(same(original.settings)));
    expect(duplicate.toolId, original.toolId);
    expect(duplicate.input.rawValue, original.input.rawValue);
    expect(duplicate.input.parserResult, isNull);
    expect(duplicate.output!.rawValue, original.output!.rawValue);
    expect(duplicate.status, WorkflowStepStatus.completed);
    expect(controller.isCurrent(0), isFalse);
    expect(controller.isCurrent(1), isFalse);
    expect(controller.isCurrent(2), isTrue);
    expect(
      steps.where(
        (WorkflowStep step) => step.status == WorkflowStepStatus.running,
      ),
      hasLength(1),
    );
    expect(
      controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000'),
      isNull,
    );
  });

  test('branch keeps an immutable origin and starts a usable alternate', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    expect(controller.branchFrom(0), isFalse);
    controller.addNext(0, UtilityCatalog.byId('number_base'), '1700000000');
    final WorkSession original = controller.session!;

    expect(controller.branchFrom(0), isTrue);

    final WorkSession alternate = controller.session!;
    expect(controller.branchOrigin, same(original));
    expect(alternate.id, isNot(original.id));
    expect(alternate.steps, hasLength(1));
    expect(alternate.steps.single, isNot(same(original.steps.first)));
    expect(
      alternate.steps.single.input,
      isNot(same(original.steps.first.input)),
    );
    expect(
      alternate.steps.single.settings,
      isNot(same(original.steps.first.settings)),
    );
    expect(
      alternate.steps.single.output!.rawValue,
      original.steps.first.output!.rawValue,
    );
    expect(alternate.steps.single.status, WorkflowStepStatus.completed);
    expect(
      controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000'),
      1,
    );
    expect(original.steps, hasLength(2));
    expect(original.steps.last.toolId, 'number_base');
    expect(original.steps.first.output!.rawValue, '1700000000');
    expect(controller.branchFrom(0), isFalse);

    controller.clear();
    expect(controller.session, isNull);
    expect(controller.branchOrigin, isNull);
  });

  test('a duplicated final completed step remains the sole continuation', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('bps'),
      artifact(ArtifactKind.bps, '25 bps'),
    );
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    controller.removeSubsequent(0);

    expect(controller.duplicate(0), isTrue);
    expect(controller.isCurrent(0), isFalse);
    expect(controller.isCurrent(1), isTrue);
    expect(
      controller.addNext(1, UtilityCatalog.byId('timestamp'), '1800000000'),
      2,
    );
    expect(
      controller.session!.steps.where(
        (WorkflowStep step) => step.status == WorkflowStepStatus.running,
      ),
      hasLength(1),
    );
    expect(controller.session!.steps.last.input.rawValue, '1800000000');
  });

  test('export fails closed for sensitive lineage with standard output', () {
    final WorkflowStep step = WorkflowStep(
      toolId: 'json',
      input: artifact(
        ArtifactKind.json,
        '{"claim":true}',
        sensitivity: ArtifactSensitivity.sensitive,
      ),
      settings: const <String, Object?>{},
      output: artifact(ArtifactKind.json, '{"safe-looking":true}'),
      status: WorkflowStepStatus.completed,
    );

    expect(WorkSessionController.canExport(step), isFalse);

    final WorkflowStep directCredential = WorkflowStep(
      toolId: 'json',
      input: artifact(ArtifactKind.json, '{"safe":true}'),
      settings: const <String, Object?>{},
      output: artifact(ArtifactKind.json, '{"password":"do-not-copy"}'),
      status: WorkflowStepStatus.completed,
    );
    expect(WorkSessionController.canExport(directCredential), isFalse);
  });
}
