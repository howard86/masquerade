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
}
