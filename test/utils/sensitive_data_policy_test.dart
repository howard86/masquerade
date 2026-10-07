import 'dart:math';

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

  test('does not mistake ordinary padded Base64 for an empty env value', () {
    expect(
      SensitiveDataPolicy.containsSensitiveArtifact('eyJvayI6dHJ1ZX0='),
      isFalse,
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

  test('keyword prefilter is equivalent to the unfiltered scan', () {
    // Oracle: the pre-prefilter patterns, verbatim.
    final RegExp credentialKey = RegExp(
      r'''(?:^|[\[\{,?&;])\s*(?:-\s*)?["']?(?:[A-Za-z0-9]+[-_.])*(?:access[-_.]?key(?:[-_.]?id)?|access[-_.]?token|api[-_.]?key|auth[-_.]?token|authorization|client[-_.]?secret|consumer[-_.]?secret|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|proxy[-_.]?authorization|pwd|refresh[-_.]?token|secret[-_.]?access[-_.]?key|secret(?:[-_.]?key)?|session[-_.]?token|token)["']?\s*[:=]''',
      caseSensitive: false,
      multiLine: true,
    );
    final RegExp env = RegExp(
      r'^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*\S',
      multiLine: true,
    );
    final RegExp privateKey = RegExp(
      r'-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----',
    );
    final RegExp jwt = RegExp(
      r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*',
    );
    bool oracle(String v) =>
        credentialKey.hasMatch(v) ||
        env.hasMatch(v) ||
        privateKey.hasMatch(v) ||
        jwt.hasMatch(v);

    const List<String> pieces = <String>[
      'access',
      'key',
      'id',
      'api',
      'auth',
      'client',
      'consumer',
      'credential',
      'credentials',
      'pass',
      'password',
      'passwd',
      'pwd',
      'private',
      'proxy',
      'refresh',
      'secret',
      'session',
      'token',
      'authorization',
      'Token',
      'PASSWORD',
      'ApiKey',
      'foo',
      'bar',
      'name',
      'x',
      '1',
      '-',
      '_',
      '.',
      ':',
      '=',
      ' ',
      '  ',
      '\t',
      '\n',
      '"',
      "'",
      '{',
      '[',
      ',',
      '&',
      '?',
      ';',
      'ſ',
      'K',
      'İ',
      'ı',
      'é',
      '😀',
      'eyJa.eyJb.c',
      '-----BEGIN PRIVATE KEY-----',
      'export ',
      'A=b',
    ];
    final Random rng = Random(20260707);
    int hits = 0;
    for (int i = 0; i < 20000; i++) {
      final StringBuffer b = StringBuffer();
      final int n = 1 + rng.nextInt(12);
      for (int j = 0; j < n; j++) {
        b.write(pieces[rng.nextInt(pieces.length)]);
      }
      final String input = b.toString();
      final bool expected = oracle(input);
      if (expected) hits++;
      expect(
        SensitiveDataPolicy.containsSensitiveArtifact(input),
        expected,
        reason: input,
      );
    }
    expect(hits, greaterThan(500));
  });
}
