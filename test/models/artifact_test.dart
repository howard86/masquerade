import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/content_type.dart';
import 'package:masquerade/utils/json_parser.dart';
import 'package:masquerade/utils/jwt_parser.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/utils/timestamp_parser.dart';

void main() {
  group('Artifact', () {
    test('retains representative parser results for reuse', () {
      const String token =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.sig';
      final JwtParseResult jwtResult = JwtParser.parse(token);
      final Artifact<JwtParseResult> jwt = Artifact<JwtParseResult>(
        kind: ArtifactKind.jwt,
        rawValue: token,
        provenance: ArtifactProvenance.clipboard,
        parserResult: jwtResult,
      );

      final TimestampParseResult timestampResult =
          TimestampParser.parseAnyFormat('1700000000');
      final Artifact<TimestampParseResult> timestamp =
          Artifact<TimestampParseResult>(
            kind: ArtifactKind.timestamp,
            rawValue: '1700000000',
            provenance: ArtifactProvenance.typed,
            parserResult: timestampResult,
          );

      final JSONParseResult jsonResult = JSONParser.parse('{"a":1}');
      final Artifact<JSONParseResult> json = Artifact<JSONParseResult>(
        kind: ArtifactKind.json,
        rawValue: '{"a":1}',
        provenance: ArtifactProvenance.generated,
        parserResult: jsonResult,
      );

      final Artifact<Object?> unknown = Artifact<Object?>(
        kind: ArtifactKind.unknown,
        rawValue: 'plain text',
        provenance: ArtifactProvenance.camera,
      );

      expect(jwtResult, isA<JwtOk>());
      expect(jwt.parserResult, same(jwtResult));
      expect(jwt.contentType, ContentType.text);
      expect(timestamp.parserResult, same(timestampResult));
      expect(timestamp.contentType, ContentType.epoch);
      expect(jsonResult, isA<JSONOk>());
      expect(json.parserResult, same(jsonResult));
      expect(json.contentType, ContentType.json);
      expect(unknown.parserResult, isNull);
      expect(unknown.contentType, ContentType.text);
      expect(unknown.safePreview, 'plain text');
    });

    test('never echoes a sensitive raw value as its safe preview', () {
      final List<Artifact<Object?>> sensitive = <Artifact<Object?>>[
        Artifact<Object?>(
          kind: ArtifactKind.jwt,
          rawValue: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature',
          provenance: ArtifactProvenance.typed,
        ),
        Artifact<Object?>(
          kind: ArtifactKind.json,
          rawValue: '{"api_key":"secret"}',
          provenance: ArtifactProvenance.clipboard,
        ),
        Artifact<Object?>(
          kind: ArtifactKind.base64,
          rawValue: 'YXBpX2tleT1zZWNyZXQ=',
          provenance: ArtifactProvenance.liveLink,
        ),
        Artifact<Object?>(
          kind: ArtifactKind.bytes,
          rawValue: '97 112 105 95 107 101 121 61 115 101 99 114 101 116',
          provenance: ArtifactProvenance.clipboard,
        ),
        Artifact<Object?>(
          kind: ArtifactKind.url,
          rawValue: 'api_key%3Dsecret',
          provenance: ArtifactProvenance.camera,
        ),
        Artifact<Object?>(
          kind: ArtifactKind.unknown,
          rawValue: SensitiveDataPolicy.mask,
          provenance: ArtifactProvenance.generated,
          sensitivity: ArtifactSensitivity.sensitive,
        ),
      ];

      for (final Artifact<Object?> artifact in sensitive) {
        expect(artifact.sensitivity, ArtifactSensitivity.sensitive);
        expect(artifact.safePreview, isNot(artifact.rawValue));
      }
    });

    test('validates preview length in release builds', () {
      expect(
        () => Artifact<Object?>(
          kind: ArtifactKind.unknown,
          rawValue: 'x',
          provenance: ArtifactProvenance.typed,
          previewLength: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('DetectionMatch', () {
    final Artifact<Object?> artifact = Artifact<Object?>(
      kind: ArtifactKind.timestamp,
      rawValue: '1700000000',
      provenance: ArtifactProvenance.typed,
    );

    test('supports multiple immutable destination tools', () {
      final DetectionMatch<Object?> match = DetectionMatch<Object?>(
        artifact: artifact,
        confidence: 0.8,
        reason: 'Plausible ten-digit Unix timestamp',
        primaryToolId: 'timestamp',
        compatibleToolIds: <String>{'timestamp', 'number_base'},
      );

      expect(match.compatibleToolIds, <String>{'timestamp', 'number_base'});
      expect(() => match.compatibleToolIds.add('math'), throwsUnsupportedError);
    });

    test('rejects invalid evidence in release builds', () {
      DetectionMatch<Object?> build({
        double confidence = 0.5,
        String reason = 'evidence',
        Set<String> tools = const <String>{'timestamp'},
        String primary = 'timestamp',
      }) => DetectionMatch<Object?>(
        artifact: artifact,
        confidence: confidence,
        reason: reason,
        primaryToolId: primary,
        compatibleToolIds: tools,
      );

      expect(() => build(confidence: -0.1), throwsArgumentError);
      expect(() => build(confidence: 1.1), throwsArgumentError);
      expect(() => build(confidence: double.nan), throwsArgumentError);
      expect(() => build(reason: '  '), throwsArgumentError);
      expect(() => build(tools: <String>{}), throwsArgumentError);
      expect(() => build(primary: 'number_base'), throwsArgumentError);
    });
  });
}
