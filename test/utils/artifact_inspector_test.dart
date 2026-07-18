import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utils/artifact_inspector.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

void main() {
  group('ArtifactInspector', () {
    test('traces URL to JWT payload JSON and timestamp', () {
      final String token = _jwt(<String, Object?>{'exp': 1700000000});
      final ArtifactInspection result = ArtifactInspector.inspect(
        'https://example.test/?token=${Uri.encodeQueryComponent(token)}',
      );

      expect(result.isSuccess, isTrue);
      expect(
        _labels(result.root!),
        containsAllInOrder(<String>[
          'URL',
          'JWT',
          'JWT payload JSON',
          'JSON',
          'Timestamp',
        ]),
      );
      expect(
        _all(result.root!).every(
          (InspectorLayer layer) =>
              layer.safePreview == SensitiveDataPolicy.mask,
        ),
        isTrue,
      );
      expect(_labels(result.root!), isNot(contains('Field "exp"')));
    });

    test('traces Base64 through explicit UTF-8 text to JSON', () {
      final String encoded = base64Encode(utf8.encode('{"ok":true}'));
      final ArtifactInspection result = ArtifactInspector.inspect(encoded);

      expect(
        _labels(result.root!),
        containsAllInOrder(<String>['Base64', 'UTF-8 text', 'JSON']),
      );
    });

    test('accepts exact byte limit and rejects one byte over', () {
      expect(
        ArtifactInspector.inspect(
          'x' * ArtifactInspector.maxTextBytes,
        ).isSuccess,
        isTrue,
      );
      final ArtifactInspection over = ArtifactInspector.inspect(
        'x' * (ArtifactInspector.maxTextBytes + 1),
      );
      expect(over.isSuccess, isFalse);
      expect(over.error, contains('64 KiB'));
    });

    test('bounds wide branches and terminates repeated normalized values', () {
      final String input = jsonEncode(<String, Object?>{
        for (int i = 0; i < 20; i++) 'field$i': 1700000000,
      });
      final ArtifactInspection first = ArtifactInspector.inspect(input);
      final ArtifactInspection second = ArtifactInspector.inspect(input);

      expect(first.nodeCount, lessThanOrEqualTo(ArtifactInspector.maxNodes));
      final InspectorLayer json = _all(
        first.root!,
      ).firstWhere((InspectorLayer layer) => layer.label == 'JSON');
      expect(json.children.length, ArtifactInspector.maxChildren);
      expect(first.truncated, isTrue);
      expect(
        _all(first.root!).where(
          (InspectorLayer layer) => layer.warning?.contains('Repeated') == true,
        ),
        isNotEmpty,
      );
      expect(_labels(first.root!), _labels(second.root!));
    });

    test('repeat normalization keeps JSON strings distinct from numbers', () {
      final ArtifactInspection result = ArtifactInspector.inspect(
        '{"string":"1700000000","number":1700000000}',
      );

      expect(
        _all(
          result.root!,
        ).where((InspectorLayer layer) => layer.label == 'Timestamp'),
        hasLength(2),
      );
    });

    test('reports nested structured branch truncation', () {
      final ArtifactInspection result = ArtifactInspector.inspect(
        jsonEncode(<String, Object?>{
          'outer': <String, int>{for (int i = 0; i < 9; i++) '$i': i},
        }),
      );

      expect(result.truncated, isTrue);
    });

    test('malformed URL escapes and wide structured input never throw', () {
      expect(() => ArtifactInspector.inspect('?a=%ZZ&b=x'), returnsNormally);
      expect(
        () => ArtifactInspector.inspect(
          jsonEncode(<String, int>{for (int i = 0; i < 4000; i++) '$i': i}),
        ),
        returnsNormally,
      );
      final String deep = '${'[' * 200}0${']' * 200}';
      expect(() => ArtifactInspector.inspect(deep), returnsNormally);
      expect(ArtifactInspector.inspect(deep).truncated, isTrue);
      expect(
        () => ArtifactInspector.inspect(base64Encode(utf8.encode(deep))),
        returnsNormally,
      );
    });

    test('inherited sensitivity masks arbitrary values and provenance', () {
      const String secret = 'not-pattern-shaped-secret';
      final ArtifactInspection result = ArtifactInspector.inspect(
        secret,
        provenance: ArtifactProvenance.generated,
        inheritedSensitive: true,
      );

      expect(result.root!.safePreview, SensitiveDataPolicy.mask);
      expect(result.root!.artifact.provenance, ArtifactProvenance.generated);
      expect(result.root!.isSensitive, isTrue);
    });

    test('standard detectors cannot bypass direct credential protection', () {
      for (final String input in <String>[
        '?api_key=raw-secret&x=y',
        '{"password":"raw-secret"}',
      ]) {
        final ArtifactInspection result = ArtifactInspector.inspect(input);
        expect(result.root!.isSensitive, isTrue, reason: input);
        expect(result.root!.safePreview, SensitiveDataPolicy.mask);
        expect(
          _all(result.root!).every(
            (InspectorLayer layer) =>
                layer.safePreview == SensitiveDataPolicy.mask,
          ),
          isTrue,
          reason: input,
        );
      }
    });
  });
}

String _jwt(Map<String, Object?> payload) {
  String segment(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment(<String, String>{'alg': 'none'})}.${segment(payload)}.';
}

List<InspectorLayer> _all(InspectorLayer root) => <InspectorLayer>[
  root,
  for (final InspectorLayer child in root.children) ..._all(child),
];

List<String> _labels(InspectorLayer root) =>
    _all(root).map((InspectorLayer layer) => layer.label).toList();
