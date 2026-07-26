import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/saved_workflow.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Artifact<Object?> _artifact(ArtifactKind kind, String raw) => Artifact<Object?>(
  kind: kind,
  rawValue: raw,
  provenance: ArtifactProvenance.typed,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('JWT workflow survives relaunch without captured payloads', () async {
    const String firstToken = 'eyJhbGciOiJub25lIn0.eyJhdCI6MTcwMDAwMDAwMH0.';
    const String secondToken = 'eyJhbGciOiJub25lIn0.eyJhdCI6MTgwMDAwMDAwMH0.';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController controller = WorkSessionController(
      prefs: prefs,
    );
    controller.start(
      UtilityCatalog.byId('jwt'),
      _artifact(ArtifactKind.jwt, firstToken),
    );
    controller.addNext(0, UtilityCatalog.byId('json'), '{"at":1700000000}');
    final WorkSession settingsLease = controller.session!;
    expect(
      controller.updateSettings(1, settingsLease, <String, Object?>{
        'source': 'json',
        'target': 'tree',
        'payload': firstToken,
      }),
      isTrue,
    );
    controller.addNext(1, UtilityCatalog.byId('timestamp'), '1700000000');
    await controller.saveCurrent('JWT debug');
    await controller.flush();

    final String persisted = prefs.getString(WorkSessionController.storageKey)!;
    expect(persisted, isNot(contains(firstToken)));
    final Map<String, dynamic> document =
        jsonDecode(persisted) as Map<String, dynamic>;
    expect(document['recentSessions'], isEmpty);
    final Map<String, dynamic> definition =
        (document['savedWorkflows'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(definition, isNot(containsPair('input', anything)));
    expect(definition, isNot(containsPair('output', anything)));
    expect(jsonEncode(definition), isNot(contains('payload')));

    final WorkSessionController restored = await WorkSessionController.load();
    final SavedWorkflow workflow = restored.savedWorkflows.single;
    expect(
      workflow.steps.map((SavedWorkflowStep step) => step.toolId),
      <String>['jwt', 'json', 'timestamp'],
    );
    expect(workflow.steps[1].settings, <String, Object?>{
      'source': 'json',
      'target': 'tree',
    });
    expect(restored.rerun(workflow, secondToken), 0);
    expect(restored.session!.steps.single.input.rawValue, secondToken);
    expect(
      restored.addNext(0, UtilityCatalog.byId('json'), '{"at":1800000000}'),
      1,
    );
    expect(restored.session!.steps[1].settings, workflow.steps[1].settings);
  });

  test('secret-like Markdown never enters recent-session storage', () async {
    const String secret =
        '# Private\n\n[endpoint](https://user:password@example.com)';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController controller = WorkSessionController(
      prefs: prefs,
    );
    final Artifact<Object?> detected = UtilityCatalog.detectArtifacts(secret)
        .firstWhere(
          (DetectionMatch<Object?> match) => match.primaryToolId == 'markdown',
        )
        .artifact;

    controller.start(UtilityCatalog.byId('markdown'), detected);
    await controller.flush();

    expect(controller.session!.steps.single.input.isSensitive, isTrue);
    expect(controller.recentSessions, isEmpty);
    expect(prefs.getString(WorkSessionController.storageKey), isNull);
  });

  test(
    'unknown saved tools stay visible while invalid recents are dropped',
    () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WorkSession safeRecent = WorkSession(
        id: 'recent-1',
        name: 'Safe recent',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
        steps: <WorkflowStep>[
          WorkflowStep(
            toolId: 'json',
            input: _artifact(ArtifactKind.json, '{}'),
            settings: const <String, Object?>{},
            status: WorkflowStepStatus.running,
          ),
        ],
      );
      final Map<String, Object?> recent = safeRecent.toJson(
        canPersistTool: (_) => true,
      );
      ((recent['steps'] as List<Object?>).single
              as Map<String, Object?>)['toolId'] =
          'removed-tool';
      await prefs.setString(
        WorkSessionController.storageKey,
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'savedWorkflows': <Object?>[
            <String, Object?>{
              'id': 'workflow-1',
              'name': 'Legacy flow',
              'createdAt': 1,
              'updatedAt': 2,
              'steps': <Object?>[
                <String, Object?>{
                  'toolId': 'removed-tool',
                  'settings': <String, Object?>{},
                },
              ],
            },
          ],
          'recentSessions': <Object?>[recent],
        }),
      );

      final WorkSessionController restored = await WorkSessionController.load();
      expect(restored.recentSessions, isEmpty);
      expect(restored.savedWorkflows.single.available, isFalse);
      expect(restored.rerun(restored.savedWorkflows.single, '{}'), isNull);
      expect(restored.workflowError, contains('removed-tool'));
      expect(restored.session, isNull);
    },
  );

  test(
    'clear removes recents after queued writes but keeps definitions',
    () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WorkSessionController controller = WorkSessionController(
        prefs: prefs,
      );
      controller.start(
        UtilityCatalog.byId('bps'),
        _artifact(ArtifactKind.bps, '25 bps'),
      );
      controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
      await controller.saveCurrent('Rates');
      await controller.clear();
      await controller.flush();

      final WorkSessionController restored = await WorkSessionController.load();
      expect(restored.recentSessions, isEmpty);
      expect(restored.savedWorkflows.single.name, 'Rates');
    },
  );

  test('strict load rejects duplicate IDs and protected names', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const Map<String, Object?> definition = <String, Object?>{
      'id': 'workflow-1',
      'name': 'Safe',
      'createdAt': 1,
      'updatedAt': 2,
      'steps': <Object?>[
        <String, Object?>{'toolId': 'json', 'settings': <String, Object?>{}},
      ],
    };
    await prefs.setString(
      WorkSessionController.storageKey,
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'savedWorkflows': <Object?>[definition, definition],
        'recentSessions': <Object?>[],
      }),
    );
    final WorkSessionController empty = await WorkSessionController.load();
    expect(empty.savedWorkflows, isEmpty);
    expect(prefs.containsKey(WorkSessionController.storageKey), isFalse);

    final WorkSessionController controller = WorkSessionController(
      prefs: prefs,
    );
    controller.start(
      UtilityCatalog.byId('bps'),
      _artifact(ArtifactKind.bps, '25 bps'),
    );
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    expect(
      await controller.saveCurrent('eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsIn0='),
      isNull,
    );
    expect(controller.savedWorkflows, isEmpty);
  });

  test('settings updates reject stale session routes', () {
    final WorkSessionController controller = WorkSessionController();
    controller.start(
      UtilityCatalog.byId('json'),
      _artifact(ArtifactKind.json, '{}'),
    );
    final WorkSession stale = controller.session!;
    controller.start(
      UtilityCatalog.byId('json'),
      _artifact(ArtifactKind.json, '{"new":true}'),
    );

    expect(
      controller.updateSettings(0, stale, <String, Object?>{'target': 'tree'}),
      isFalse,
    );
    expect(controller.session!.steps.single.settings, isEmpty);
  });

  test('rename and delete persist atomically', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController controller = WorkSessionController(
      prefs: prefs,
    );
    controller.start(
      UtilityCatalog.byId('bps'),
      _artifact(ArtifactKind.bps, '25 bps'),
    );
    controller.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    final SavedWorkflow first = (await controller.saveCurrent('First'))!;
    final SavedWorkflow second = (await controller.saveCurrent('Second'))!;

    expect(await controller.renameWorkflow(first.id, 'Renamed'), isTrue);
    expect(await controller.deleteWorkflow(second.id), isTrue);
    final WorkSessionController restored = await WorkSessionController.load();
    expect(restored.savedWorkflows.single.name, 'Renamed');
  });

  test('future and malformed persisted schemas fail closed', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, Object?> recent = WorkSession(
      id: 'duplicate-recent',
      name: 'Recent',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
      steps: <WorkflowStep>[
        WorkflowStep(
          toolId: 'json',
          input: _artifact(ArtifactKind.json, '{}'),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.running,
        ),
      ],
    ).toJson(canPersistTool: (_) => true);
    for (final Object payload in <Object>[
      <String, Object?>{
        'schemaVersion': 2,
        'savedWorkflows': <Object?>[],
        'recentSessions': <Object?>[],
      },
      <String, Object?>{
        'schemaVersion': 1,
        'savedWorkflows': <Object?>[],
        'recentSessions': <Object?>[recent, recent],
      },
      <String, Object?>{
        'schemaVersion': 1,
        'savedWorkflows': <Object?>[
          <String, Object?>{
            'id': 'bad',
            'name': 'Bad',
            'createdAt': 1,
            'updatedAt': 2,
            'steps': <Object?>[],
          },
        ],
        'recentSessions': <Object?>[],
      },
    ]) {
      await prefs.setString(
        WorkSessionController.storageKey,
        jsonEncode(payload),
      );
      final WorkSessionController restored = await WorkSessionController.load();
      expect(restored.savedWorkflows, isEmpty);
      expect(prefs.containsKey(WorkSessionController.storageKey), isFalse);
    }
  });
}
