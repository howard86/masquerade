import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

void main() {
  Artifact<Object?> artifact(
    ArtifactKind kind,
    String value, {
    ArtifactProvenance provenance = ArtifactProvenance.typed,
    Object? parserResult,
  }) => Artifact<Object?>(
    kind: kind,
    rawValue: value,
    provenance: provenance,
    parserResult: parserResult,
  );

  WorkSession fixture() => WorkSession(
    id: 'session-1',
    name: 'Inspect response',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000009000),
    steps: <WorkflowStep>[
      WorkflowStep(
        toolId: 'json',
        input: artifact(
          ArtifactKind.json,
          '{"timestamp":1700000000}',
          provenance: ArtifactProvenance.clipboard,
          parserResult: const <String, int>{'timestamp': 1700000000},
        ),
        settings: <String, Object?>{'indent': 2, 'sortKeys': true},
        output: artifact(
          ArtifactKind.json,
          '{\n  "timestamp": 1700000000\n}',
          provenance: ArtifactProvenance.generated,
        ),
        status: WorkflowStepStatus.completed,
      ),
      WorkflowStep(
        toolId: 'timestamp',
        input: artifact(ArtifactKind.timestamp, '1700000000'),
        settings: <String, Object?>{'unit': 'seconds'},
        output: artifact(
          ArtifactKind.timestamp,
          '2023-11-14T22:13:20.000Z',
          provenance: ArtifactProvenance.generated,
        ),
        status: WorkflowStepStatus.completed,
      ),
    ],
  );

  test('multi-step session round-trips in order without parser state', () {
    final Map<String, Object?> encoded = fixture().toJson(
      canPersistTool: (_) => true,
    );
    final WorkSession? restored = WorkSession.tryFromJson(
      jsonDecode(jsonEncode(encoded)),
      isKnownTool: (String id) => id == 'json' || id == 'timestamp',
    );

    expect(restored, isNotNull);
    expect(restored!.id, 'session-1');
    expect(restored.name, 'Inspect response');
    expect(restored.createdAt.millisecondsSinceEpoch, 1700000000000);
    expect(restored.updatedAt.millisecondsSinceEpoch, 1700000009000);
    expect(restored.steps.map((WorkflowStep step) => step.toolId), <String>[
      'json',
      'timestamp',
    ]);
    expect(restored.steps.first.settings, <String, Object?>{
      'indent': 2,
      'sortKeys': true,
    });
    expect(restored.steps.first.input.parserResult, isNull);
    expect(restored.steps.last.output!.rawValue, '2023-11-14T22:13:20.000Z');
    expect(
      restored.steps.every((WorkflowStep step) => step.toolAvailable),
      isTrue,
    );
  });

  test('unknown tools restore as unavailable without losing their id', () {
    final Map<String, Object?> encoded = fixture().toJson(
      canPersistTool: (_) => true,
    );
    final List<Object?> steps = encoded['steps']! as List<Object?>;
    (steps.first as Map<String, Object?>)['toolId'] = 'removed-tool';

    final WorkSession? restored = WorkSession.tryFromJson(
      jsonDecode(jsonEncode(encoded)),
      isKnownTool: (String id) => id != 'removed-tool',
    );

    expect(restored!.steps.first.toolId, 'removed-tool');
    expect(restored.steps.first.toolAvailable, isFalse);
    expect(restored.steps.first.status, WorkflowStepStatus.completed);
    expect(restored.steps.first.input.rawValue, SensitiveDataPolicy.mask);
    expect(restored.steps.first.output!.rawValue, SensitiveDataPolicy.mask);
    expect(restored.steps.first.settings, isEmpty);
  });

  test('rejects malformed, old, and future schemas without throwing', () {
    final Map<String, Object?> encoded = fixture().toJson(
      canPersistTool: (_) => true,
    );

    expect(WorkSession.tryFromJson(null), isNull);
    expect(
      WorkSession.tryFromJson(<String, Object?>{
        ...encoded,
        'schemaVersion': 0,
      }),
      isNull,
    );
    expect(
      WorkSession.tryFromJson(<String, Object?>{
        ...encoded,
        'schemaVersion': 2,
      }),
      isNull,
    );
    expect(
      WorkSession.tryFromJson(<String, Object?>{...encoded, 'steps': 'nope'}),
      isNull,
    );
    final Map<String, Object?> malformed =
        jsonDecode(jsonEncode(encoded)) as Map<String, Object?>;
    ((malformed['steps']! as List<Object?>).first
        as Map<String, Object?>)['settings'] = <String, Object?>{
      'bad': DateTime(2026),
    };
    expect(WorkSession.tryFromJson(malformed), isNull);
    expect(
      () => WorkflowStep(
        toolId: 'json',
        input: artifact(ArtifactKind.json, '{}'),
        settings: <String, Object?>{'scale': double.nan},
        status: WorkflowStepStatus.pending,
      ),
      throwsArgumentError,
    );
  });

  test('serialization redacts artifacts and recursively scrubs settings', () {
    const String credential = 'raw-credential-fixture';
    const String base64Credential =
        'eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsLWZpeHR1cmUifQ==';
    const String bytesCredential =
        '123 34 112 97 115 115 119 111 114 100 34 58 34 114 97 119 45 99 114 101 100 101 110 116 105 97 108 45 102 105 120 116 117 114 101 34 125';
    const String urlCredential =
        '%7B%22password%22%3A%22raw-credential-fixture%22%7D';
    final WorkSession session = WorkSession(
      id: 'protected',
      name: base64Credential,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
      steps: <WorkflowStep>[
        WorkflowStep(
          toolId: 'generator',
          input: artifact(ArtifactKind.unknown, 'generated input'),
          settings: <String, Object?>{
            'length': 24,
            'type': 'hex',
            'options': <Object?>['upper', true],
            'password': credential,
            'nested': <String, Object?>{'format': 'text', 'output': credential},
            'generatedPayload': credential,
          },
          output: artifact(ArtifactKind.unknown, credential),
          status: WorkflowStepStatus.completed,
        ),
        WorkflowStep(
          toolId: 'base64',
          input: artifact(ArtifactKind.base64, base64Credential),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.pending,
        ),
        WorkflowStep(
          toolId: 'bytes',
          input: artifact(ArtifactKind.bytes, bytesCredential),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.pending,
        ),
        WorkflowStep(
          toolId: 'url',
          input: artifact(ArtifactKind.url, urlCredential),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.pending,
        ),
        WorkflowStep(
          toolId: 'json',
          input: artifact(ArtifactKind.unknown, base64Credential),
          settings: const <String, Object?>{},
          status: WorkflowStepStatus.pending,
        ),
        WorkflowStep(
          toolId: 'json',
          input: artifact(ArtifactKind.json, '{"safe":true}'),
          settings: <String, Object?>{
            'format': 'pretty',
            'nested': <String, Object?>{
              'values': <Object?>[
                'safe-token',
                base64Credential,
                bytesCredential,
                urlCredential,
              ],
              base64Credential: 'encoded credential key',
              'byteArray': bytesCredential.split(' ').map(int.parse).toList(),
            },
          },
          status: WorkflowStepStatus.pending,
        ),
      ],
    );

    final Map<String, Object?> encoded = session.toJson(
      canPersistTool: (String id) =>
          historyPolicyFor(id) == HistoryPolicy.enabled,
    );
    final String serialized = jsonEncode(encoded);
    for (final String secret in <String>[
      credential,
      base64Credential,
      bytesCredential,
      urlCredential,
    ]) {
      expect(serialized, isNot(contains(secret)));
    }
    final List<dynamic> steps = encoded['steps']! as List<dynamic>;
    final Map<String, dynamic> generator = steps.first as Map<String, dynamic>;
    expect(generator['input'], <String, Object?>{
      'kind': 'unknown',
      'provenance': 'typed',
      'redacted': true,
    });
    expect(generator['settings'], isEmpty);
    expect(encoded['name'], 'Untitled session');
    expect((steps.last as Map<String, dynamic>)['settings'], <String, Object?>{
      'format': 'pretty',
      'nested': <String, Object?>{
        'values': <Object?>['safe-token'],
      },
    });
    expect(serialized, isNot(contains('parserResult')));
    expect(serialized, isNot(contains('liveLink')));
    expect(serialized, isNot(contains('linkGroup')));

    final WorkSession restored = WorkSession.tryFromJson(
      jsonDecode(serialized),
    )!;
    expect(restored.steps.first.input.rawValue, SensitiveDataPolicy.mask);
    expect(restored.steps.first.output!.rawValue, SensitiveDataPolicy.mask);
    expect(restored.steps.first.input.isSensitive, isTrue);

    final Map<String, Object?> tampered = fixture().toJson(
      canPersistTool: (_) => true,
    );
    tampered['name'] = urlCredential;
    final Map<String, Object?> tamperedInput =
        ((tampered['steps']! as List<Object?>).first
                as Map<String, Object?>)['input']
            as Map<String, Object?>;
    tamperedInput
      ..['kind'] = 'unknown'
      ..['rawValue'] = base64Credential;
    final WorkSession decoded = WorkSession.tryFromJson(
      jsonDecode(jsonEncode(tampered)),
      isKnownTool: (_) => true,
    )!;
    expect(decoded.name, 'Untitled session');
    expect(decoded.steps.first.input.rawValue, SensitiveDataPolicy.mask);
  });

  test('deep-freezes nested settings', () {
    final List<Object?> options = <Object?>[
      <String, Object?>{'format': 'hex'},
    ];
    final WorkflowStep step = WorkflowStep(
      toolId: 'generator',
      input: artifact(ArtifactKind.unknown, ''),
      settings: <String, Object?>{'options': options},
      status: WorkflowStepStatus.pending,
    );

    (options.first as Map<String, Object?>)['format'] = 'text';
    options.add('late mutation');

    final List<Object?> frozen = step.settings['options']! as List<Object?>;
    expect(frozen, <Object?>[
      <String, Object?>{'format': 'hex'},
    ]);
    expect(() => frozen.add('nope'), throwsUnsupportedError);
    expect(
      () => (frozen.first as Map<String, Object?>)['format'] = 'nope',
      throwsUnsupportedError,
    );
  });
}
