import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';

void main() {
  test('inspector next step keeps lineage protected and out of recents', () {
    final WorkSessionController sessions = WorkSessionController();
    final UtilityDescriptor inspector = UtilityCatalog.byId(
      'artifact_inspector',
    );
    final UtilityDescriptor json = UtilityCatalog.byId('json');
    final int step = sessions.start(
      inspector,
      Artifact<Object?>(
        kind: ArtifactKind.base64,
        rawValue: 'eyJvayI6dHJ1ZX0=',
        provenance: ArtifactProvenance.clipboard,
      ),
    );

    final int? next = sessions.addNext(step, json, '{"ok":true}');

    expect(next, 1);
    expect(sessions.session!.steps.first.input.isSensitive, isTrue);
    expect(sessions.session!.steps.first.output!.isSensitive, isTrue);
    expect(sessions.session!.steps.last.input.isSensitive, isTrue);
    expect(sessions.recentSessions, isEmpty);
  });
}
