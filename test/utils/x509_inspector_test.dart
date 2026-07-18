import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/utils/x509_inspector.dart';

void main() {
  final String leaf = _fixture('x509_leaf.pem');
  final String root = _fixture('x509_root.pem');

  group('X509Inspector', () {
    test('parses approved RSA certificate fields, SANs, and fingerprints', () {
      final X509CertificateInfo certificate = X509Inspector.parse(
        leaf,
        now: DateTime.utc(2026, 8),
      ).certificates.single;

      expect(certificate.subject, contains('CN=api.example.test'));
      expect(certificate.issuer, contains('CN=Masquerade-Test-Root'));
      expect(certificate.notBefore, DateTime.utc(2026, 7, 18, 0, 57, 22));
      expect(certificate.notAfter, DateTime.utc(2027, 7, 18, 0, 57, 22));
      expect(certificate.publicKeyAlgorithm, 'RSA');
      expect(certificate.publicKeyBits, 2048);
      expect(
        certificate.sans,
        containsAll(<String>[
          'DNS:api.example.test',
          'DNS:www.example.test',
          'IP:192.0.2.10',
          'email:ops@example.test',
          'URI:https://example.test/status',
        ]),
      );
      expect(
        certificate.sha256Hex,
        '4db55802543eb850fdede2d15b3ba26e541e9f9855e3efd3a0f8dc2ad06618a8',
      );
      expect(certificate.sha1Hex, 'f528b83b8ed0c2d163501c232d8e8fa4b85ef1f9');
    });

    test('preserves leaf-to-root order and parses GeneralizedTime', () {
      final X509Inspection chain = X509Inspector.parse(
        '$leaf\n$root',
        now: DateTime.utc(2026, 8),
      );

      expect(chain.certificates, hasLength(2));
      expect(chain.certificates.first.subject, contains('api.example.test'));
      expect(chain.certificates.last.subject, contains('Masquerade-Test-Root'));
      expect(chain.certificates.last.notAfter.year, 2059);
      expect(
        chain.warnings.where(
          (String warning) => warning.contains('does not match'),
        ),
        isEmpty,
      );
      expect(
        chain.warnings,
        contains('Signatures and trust are not verified.'),
      );
    });

    test(
      'reports ordering and expiry warnings without claiming verification',
      () {
        final X509Inspection reversed = X509Inspector.parse(
          '$root\n$leaf',
          now: DateTime.utc(2028),
        );

        expect(reversed.warnings, contains('Certificate 2 has expired.'));
        expect(
          reversed.warnings,
          contains(
            'Certificate 1 issuer does not match certificate 2 subject.',
          ),
        );
      },
    );

    test('uses inclusive validity and 30-day warning boundaries', () {
      final X509CertificateInfo certificate = X509Inspector.parse(
        leaf,
      ).certificates.single;
      expect(
        X509Inspector.parse(leaf, now: certificate.notBefore).warnings,
        isNot(contains('Certificate 1 is not valid yet.')),
      );
      expect(
        X509Inspector.parse(leaf, now: certificate.notAfter).warnings,
        contains('Certificate 1 has expired.'),
      );
      expect(
        X509Inspector.parse(
          leaf,
          now: certificate.notAfter.subtract(const Duration(days: 30)),
        ).warnings,
        contains('Certificate 1 expires within 30 days.'),
      );
    });

    test('round trips canonical PEM, base64 DER, and hex DER', () {
      final X509CertificateInfo original = X509Inspector.parse(
        leaf,
      ).certificates.single;
      for (final String encoded in <String>[
        original.pem,
        original.derBase64,
        original.derHex,
      ]) {
        final X509CertificateInfo roundTrip = X509Inspector.parse(
          encoded,
        ).certificates.single;
        expect(roundTrip.der, orderedEquals(original.der));
        expect(
          roundTrip.pem
              .split('\n')
              .skip(1)
              .takeWhile((line) => !line.startsWith('---'))
              .every((line) => line.length <= 64),
          isTrue,
        );
      }
    });

    test('parses P-256 and IPv6 SAN fixture', () {
      final X509CertificateInfo certificate = X509Inspector.parse(
        _fixture('x509_ec_ipv6.pem'),
      ).certificates.single;

      expect(certificate.keyDescription, 'EC P-256 · 256 bits');
      expect(certificate.sans, contains('IP:2001:db8:0:0:0:0:0:1'));
    });

    test(
      'rejects every private-key label before mixed certificate parsing',
      () {
        for (final String label in <String>[
          'PRIVATE KEY',
          'RSA PRIVATE KEY',
          'EC PRIVATE KEY',
          'ENCRYPTED PRIVATE KEY',
          'OPENSSH PRIVATE KEY',
        ]) {
          expect(
            () => X509Inspector.parse(
              '$leaf\n-----BEGIN $label-----\nnot-key\n-----END $label-----',
            ),
            throwsA(
              isA<X509InspectorException>()
                  .having((e) => e.privateKey, 'privateKey', isTrue)
                  .having((e) => e.message, 'message', privateKeyWarning),
            ),
          );
        }
        expect(
          () => X509Inspector.parse(_fixture('x509_private_key.pem')),
          throwsA(isA<X509InspectorException>()),
        );
      },
    );

    test('rejects non-canonical, deep, trailing, and malformed DER safely', () {
      final Uint8List valid = X509Inspector.parse(leaf).certificates.single.der;
      final Uint8List invalidVersion = Uint8List.fromList(valid);
      final int version = _find(invalidVersion, <int>[0xa0, 3, 2, 1, 2]);
      invalidVersion[version + 4] = 3;
      final Uint8List explicitDefaultVersion = Uint8List.fromList(valid);
      explicitDefaultVersion[version + 4] = 0;

      final Uint8List explicitFalseCritical = Uint8List.fromList(valid);
      final int critical = _find(explicitFalseCritical, <int>[1, 1, 0xff]);
      explicitFalseCritical[critical + 2] = 0;

      final Uint8List inverted = Uint8List.fromList(valid);
      final List<int> notAfter = ascii.encode('270718005722Z');
      final int notAfterOffset = _find(inverted, notAfter);
      inverted.setRange(
        notAfterOffset,
        notAfterOffset + notAfter.length,
        ascii.encode('250718005722Z'),
      );

      Uint8List deep = Uint8List.fromList(<int>[0x05, 0x00]);
      for (int i = 0; i < X509Inspector.maxDepth + 1; i++) {
        deep = Uint8List.fromList(<int>[0x30, deep.length, ...deep]);
      }

      for (final Uint8List bad in <Uint8List>[
        Uint8List.fromList(<int>[0x30, 0x80, 0, 0]),
        Uint8List.fromList(<int>[0x30, 0x81, 0x01, 0]),
        Uint8List.fromList(<int>[
          0x30,
          0x82,
          0,
          0x80,
          ...List<int>.filled(128, 0),
        ]),
        Uint8List.fromList(<int>[0x3f, 0]),
        Uint8List.fromList(<int>[...valid, 0]),
        invalidVersion,
        explicitDefaultVersion,
        explicitFalseCritical,
        inverted,
        deep,
      ]) {
        expect(
          () => X509Inspector.parse('base64:${base64Encode(bad)}'),
          throwsA(isA<X509InspectorException>()),
        );
      }
      expect(
        () => X509Inspector.parse(_fixture('x509_empty_san.pem')),
        throwsA(isA<X509InspectorException>()),
      );
    });

    test('bounds input and never reflects malformed values in errors', () {
      const String secret = 'do-not-reflect-this-value';
      expect(
        () => X509Inspector.parse('base64:$secret'),
        throwsA(
          isA<X509InspectorException>().having(
            (e) => e.message,
            'message',
            isNot(contains(secret)),
          ),
        ),
      );
      expect(
        () => X509Inspector.parse('x' * (X509Inspector.maxInputBytes + 1)),
        throwsA(isA<X509InspectorException>()),
      );
      expect(
        () => X509Inspector.parse(
          List<String>.filled(X509Inspector.maxCertificates + 1, leaf).join(),
        ),
        throwsA(isA<X509InspectorException>()),
      );
      expect(
        () => X509Inspector.parse(
          'base64:${base64Encode(List<int>.filled(X509Inspector.maxCertificateBytes + 1, 0))}',
        ),
        throwsA(isA<X509InspectorException>()),
      );
    });

    test('validates versioned fields, extensions, and empty-name rules', () {
      final Uint8List valid = X509Inspector.parse(leaf).certificates.single.der;
      final List<String> rejected = <String>[
        _mutate(valid, (_TestTlv root) {
          final _TestTlv tbs = root.children[0];
          tbs.children.removeAt(0); // Omit version: v1.
          tbs.children.insert(6, _TestTlv.primitive(0x81, <int>[0, 0x80]));
        }),
        _mutate(valid, (_TestTlv root) {
          _extensions(root).children.clear();
        }),
        _mutate(valid, (_TestTlv root) {
          final List<_TestTlv> extensions = _extensions(root).children;
          extensions.add(extensions[1]); // Duplicate Basic Constraints OID.
        }),
        _mutate(valid, (_TestTlv root) {
          final _TestTlv extension = _extensions(root).children.first;
          extension.children[0] = _TestTlv.primitive(0x06, <int>[42, 3, 4]);
          extension.children.last = _TestTlv.primitive(0x05, const <int>[]);
        }),
        _mutate(valid, (_TestTlv root) {
          root.children[0].children[3].children.clear(); // Empty issuer.
        }),
        _mutate(valid, (_TestTlv root) {
          final _TestTlv tbs = root.children[0];
          tbs.children[5].children.clear(); // Empty subject.
          _extensions(root).children.removeAt(0); // No SAN.
        }),
      ];
      for (final String encoded in rejected) {
        expect(
          () => X509Inspector.parse(encoded),
          throwsA(isA<X509InspectorException>()),
        );
      }

      final String criticalSanWithEmptySubject = _mutate(valid, (
        _TestTlv root,
      ) {
        root.children[0].children[5].children.clear();
        _extensions(root).children.first.children.insert(
          1,
          _TestTlv.primitive(0x01, <int>[0xff]),
        );
      });
      expect(
        X509Inspector.parse(
          criticalSanWithEmptySubject,
        ).certificates.single.subject,
        '(empty name)',
      );
    });

    test('certificate and key values never enter persisted tool state', () {
      expect(
        SensitiveDataPolicy.persistedValue(leaf, utilityId: 'x509_inspector'),
        isNull,
      );
      expect(
        SensitiveDataPolicy.persistedValue(
          _fixture('x509_private_key.pem'),
          utilityId: 'x509_inspector',
        ),
        isNull,
      );
    });
  });
}

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync().trim();

int _find(List<int> bytes, List<int> needle) {
  for (int start = 0; start <= bytes.length - needle.length; start++) {
    bool match = true;
    for (int offset = 0; offset < needle.length; offset++) {
      if (bytes[start + offset] != needle[offset]) {
        match = false;
        break;
      }
    }
    if (match) return start;
  }
  throw StateError('Fixture token not found');
}

String _mutate(Uint8List der, void Function(_TestTlv root) change) {
  final _TestTlv root = _TestTlv.parse(der);
  change(root);
  return 'base64:${base64Encode(root.encode())}';
}

_TestTlv _extensions(_TestTlv certificate) =>
    certificate.children[0].children.last.children.single;

class _TestTlv {
  _TestTlv.primitive(this.tag, List<int> value)
    : value = Uint8List.fromList(value),
      children = <_TestTlv>[];

  _TestTlv.constructed(this.tag, this.children) : value = Uint8List(0);

  final int tag;
  Uint8List value;
  final List<_TestTlv> children;

  static _TestTlv parse(Uint8List bytes) {
    final (_TestTlv, int) parsed = _parseAt(bytes, 0);
    if (parsed.$2 != bytes.length) throw const FormatException();
    return parsed.$1;
  }

  static (_TestTlv, int) _parseAt(Uint8List bytes, int offset) {
    final int tag = bytes[offset++];
    final int first = bytes[offset++];
    int length;
    if (first & 0x80 == 0) {
      length = first;
    } else {
      final int count = first & 0x7f;
      length = 0;
      for (int index = 0; index < count; index++) {
        length = (length << 8) | bytes[offset++];
      }
    }
    final int end = offset + length;
    if (tag & 0x20 == 0) {
      return (_TestTlv.primitive(tag, bytes.sublist(offset, end)), end);
    }
    final List<_TestTlv> children = <_TestTlv>[];
    while (offset < end) {
      final (_TestTlv, int) child = _parseAt(bytes, offset);
      children.add(child.$1);
      offset = child.$2;
    }
    return (_TestTlv.constructed(tag, children), end);
  }

  Uint8List encode() {
    final List<int> body = tag & 0x20 == 0
        ? value
        : <int>[for (final _TestTlv child in children) ...child.encode()];
    return Uint8List.fromList(<int>[tag, ..._length(body.length), ...body]);
  }

  static List<int> _length(int length) {
    if (length < 128) return <int>[length];
    final List<int> bytes = <int>[];
    for (int value = length; value > 0; value >>= 8) {
      bytes.insert(0, value & 0xff);
    }
    return <int>[0x80 | bytes.length, ...bytes];
  }
}
