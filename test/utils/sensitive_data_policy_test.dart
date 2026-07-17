import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';

void main() {
  const String credential = '{"password":"raw-credential-fixture"}';

  test('safePreview never echoes credential values', () {
    final String preview = SensitiveDataPolicy.safePreview(
      credential,
      max: 100,
    );

    expect(preview, SensitiveDataPolicy.mask);
    expect(preview, isNot(contains('raw-credential-fixture')));
  });

  test('detects secret keys in URL queries and YAML lists', () {
    expect(
      SensitiveDataPolicy.containsSensitiveArtifact(
        'https://example.test?api_key=raw-credential-fixture',
      ),
      isTrue,
    );
    expect(
      SensitiveDataPolicy.containsSensitiveArtifact(
        '- password: raw-credential-fixture',
      ),
      isTrue,
    );
  });

  test('persistedValue rejects sensitive tools without shape guessing', () {
    expect(
      SensitiveDataPolicy.persistedValue(
        'opaque-generated-fixture',
        utilityId: 'generator',
      ),
      isNull,
    );
  });

  test('persistedValue rejects reversible credential encodings', () {
    const String base64Credential =
        'eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsLWZpeHR1cmUifQ==';
    const String bytesCredential =
        '123 34 112 97 115 115 119 111 114 100 34 58 34 114 97 119 45 99 114 101 100 101 110 116 105 97 108 45 102 105 120 116 117 114 101 34 125';
    const String urlCredential =
        '%7B%22password%22%3A%22raw-credential-fixture%22%7D';

    expect(
      SensitiveDataPolicy.persistedValue(base64Credential, utilityId: 'base64'),
      isNull,
    );
    expect(
      SensitiveDataPolicy.persistedValue(bytesCredential, utilityId: 'bytes'),
      isNull,
    );
    expect(
      SensitiveDataPolicy.persistedValue(urlCredential, utilityId: 'url'),
      isNull,
    );
    expect(
      SensitiveDataPolicy.persistedValue('aGVsbG8=', utilityId: 'base64'),
      'aGVsbG8=',
    );
  });

  test('safePreview preserves and truncates ordinary values', () {
    expect(
      SensitiveDataPolicy.safePreview('ordinary-value', max: 8),
      'ordinary…',
    );
  });
}
