import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String privateKeyWarning =
    'Private key detected. Remove it before inspecting certificates.';

class X509InspectorException implements Exception {
  const X509InspectorException(this.message, {this.privateKey = false});

  final String message;
  final bool privateKey;
}

class X509CertificateInfo {
  const X509CertificateInfo({
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    required this.sans,
    required this.sha1Hex,
    required this.sha256Hex,
    required this.publicKeyAlgorithm,
    required this.publicKeyBits,
    required this.der,
    required this.pem,
    required this.subjectDer,
    required this.issuerDer,
  });

  final String subject;
  final String issuer;
  final DateTime notBefore;
  final DateTime notAfter;
  final List<String> sans;
  final String sha1Hex;
  final String sha256Hex;
  final String publicKeyAlgorithm;
  final int? publicKeyBits;
  final Uint8List der;
  final String pem;
  final Uint8List subjectDer;
  final Uint8List issuerDer;

  String get keyDescription => publicKeyBits == null
      ? publicKeyAlgorithm
      : '$publicKeyAlgorithm · $publicKeyBits bits';

  String get derBase64 => 'base64:${base64Encode(der)}';

  String get derHex =>
      'hex:${der.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

  String get bytesInput => der.join(' ');
}

class X509Inspection {
  const X509Inspection({required this.certificates, required this.warnings});

  final List<X509CertificateInfo> certificates;
  final List<String> warnings;
}

abstract final class X509Inspector {
  static const int maxInputBytes = 512 * 1024;
  static const int maxCertificateBytes = 128 * 1024;
  static const int maxCertificates = 16;
  static const int maxNodes = 1024;
  static const int maxDepth = 20;
  static const int maxTextBytes = 8192;
  static const int maxSans = 100;

  static final RegExp _privateKeyMarker = RegExp(
    r'-----BEGIN [^-\r\n]*PRIVATE KEY-----',
    caseSensitive: false,
  );
  static final RegExp _pemBlock = RegExp(
    r'-----BEGIN ([A-Z0-9 ]+)-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END \1-----',
  );

  static bool containsPrivateKey(String input) =>
      _privateKeyMarker.hasMatch(input);

  static X509Inspection parse(String input, {DateTime? now}) {
    if (containsPrivateKey(input)) {
      throw const X509InspectorException(privateKeyWarning, privateKey: true);
    }
    if (input.length > maxInputBytes ||
        utf8.encode(input).length > maxInputBytes) {
      throw const X509InspectorException('Certificate input is too large.');
    }
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const X509InspectorException('Paste a certificate to inspect.');
    }

    final List<Uint8List> encoded = trimmed.startsWith('-----BEGIN ')
        ? _decodePem(trimmed)
        : <Uint8List>[_decodeTextDer(trimmed)];
    if (encoded.length > maxCertificates) {
      throw const X509InspectorException('Certificate chain is too long.');
    }

    try {
      final List<X509CertificateInfo> certificates = encoded
          .map(_parseCertificate)
          .toList(growable: false);
      final List<String> warnings = <String>[
        'Signatures and trust are not verified.',
      ];
      final DateTime clock = (now ?? DateTime.now()).toUtc();
      for (int index = 0; index < certificates.length; index++) {
        final X509CertificateInfo cert = certificates[index];
        if (clock.isBefore(cert.notBefore)) {
          warnings.add('Certificate ${index + 1} is not valid yet.');
        } else if (!clock.isBefore(cert.notAfter)) {
          warnings.add('Certificate ${index + 1} has expired.');
        } else if (cert.notAfter.difference(clock) <=
            const Duration(days: 30)) {
          warnings.add('Certificate ${index + 1} expires within 30 days.');
        }
        if (index + 1 < certificates.length &&
            !_sameBytes(cert.issuerDer, certificates[index + 1].subjectDer)) {
          warnings.add(
            'Certificate ${index + 1} issuer does not match certificate ${index + 2} subject.',
          );
        }
      }
      return X509Inspection(
        certificates: List<X509CertificateInfo>.unmodifiable(certificates),
        warnings: List<String>.unmodifiable(warnings),
      );
    } on X509InspectorException {
      rethrow;
    } catch (_) {
      throw const X509InspectorException(
        'Certificate data is malformed or unsupported.',
      );
    }
  }

  static List<Uint8List> _decodePem(String input) {
    final List<Uint8List> result = <Uint8List>[];
    int cursor = 0;
    for (final RegExpMatch match in _pemBlock.allMatches(input)) {
      if (input.substring(cursor, match.start).trim().isNotEmpty ||
          match.group(1) != 'CERTIFICATE') {
        throw const X509InspectorException(
          'Only CERTIFICATE PEM blocks are supported.',
        );
      }
      cursor = match.end;
      try {
        final Uint8List der = base64Decode(
          match.group(2)!.replaceAll(RegExp(r'\s'), ''),
        );
        _checkCertificateSize(der);
        result.add(der);
      } catch (_) {
        throw const X509InspectorException('Certificate PEM is malformed.');
      }
    }
    if (result.isEmpty || input.substring(cursor).trim().isNotEmpty) {
      throw const X509InspectorException('Certificate PEM is malformed.');
    }
    return result;
  }

  static Uint8List _decodeTextDer(String input) {
    try {
      final Uint8List der;
      if (input.toLowerCase().startsWith('base64:')) {
        der = base64Decode(input.substring(7).replaceAll(RegExp(r'\s'), ''));
      } else if (input.toLowerCase().startsWith('hex:')) {
        final String hex = input.substring(4).replaceAll(RegExp(r'[\s:]'), '');
        if (hex.isEmpty ||
            hex.length.isOdd ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
          throw const FormatException();
        }
        der = Uint8List.fromList(<int>[
          for (int i = 0; i < hex.length; i += 2)
            int.parse(hex.substring(i, i + 2), radix: 16),
        ]);
      } else {
        throw const X509InspectorException(
          'Use CERTIFICATE PEM, base64:DER, or hex:DER input.',
        );
      }
      _checkCertificateSize(der);
      return der;
    } on X509InspectorException {
      rethrow;
    } catch (_) {
      throw const X509InspectorException('DER encoding is malformed.');
    }
  }

  static void _checkCertificateSize(Uint8List der) {
    if (der.isEmpty || der.length > maxCertificateBytes) {
      throw const X509InspectorException('Certificate DER size is invalid.');
    }
  }

  static X509CertificateInfo _parseCertificate(Uint8List der) {
    final _DerNode certificate = _DerParser(der).parseRoot();
    _expect(certificate, 0x30, exactChildren: 3);
    _validateAlgorithmIdentifier(certificate.children[1], der);
    _validateBitString(certificate.children[2], der);
    final _DerNode tbs = certificate.children[0];
    _expect(tbs, 0x30, children: 6);

    int index = 0;
    int versionNumber = 0;
    if (tbs.children.first.tag == 0xa0) {
      final _DerNode version = tbs.children.first;
      _expect(version, 0xa0, exactChildren: 1);
      versionNumber = _smallNonnegativeInteger(version.children.single, der);
      if (versionNumber == 0 || versionNumber > 2) {
        throw const FormatException();
      }
      index++;
    }
    _integerBits(tbs.children[index++], der); // positive, canonical serial
    final _DerNode signatureAlgorithm = tbs.children[index++];
    _validateAlgorithmIdentifier(signatureAlgorithm, der);
    if (!_sameBytes(
      signatureAlgorithm.encoded(der),
      certificate.children[1].encoded(der),
    )) {
      throw const FormatException();
    }
    final _DerNode issuer = tbs.children[index++];
    final _DerNode validity = tbs.children[index++];
    final _DerNode subject = tbs.children[index++];
    final _DerNode spki = tbs.children[index++];
    final List<_DerNode> optionalFields = tbs.children.skip(index).toList();
    _validateOptionalFields(optionalFields, versionNumber, der);
    _expect(validity, 0x30, exactChildren: 2);

    final (String, int?) key = _parsePublicKey(spki);
    final ({List<String> names, bool critical}) sans = _parseSans(
      optionalFields,
      der,
    );
    if (issuer.children.isEmpty ||
        (subject.children.isEmpty && (sans.names.isEmpty || !sans.critical))) {
      throw const FormatException();
    }
    final Uint8List subjectDer = subject.encoded(der);
    final Uint8List issuerDer = issuer.encoded(der);
    final DateTime notBefore = _parseTime(validity.children[0], der);
    final DateTime notAfter = _parseTime(validity.children[1], der);
    if (!notAfter.isAfter(notBefore)) throw const FormatException();
    return X509CertificateInfo(
      subject: _parseName(subject, der),
      issuer: _parseName(issuer, der),
      notBefore: notBefore,
      notAfter: notAfter,
      sans: List<String>.unmodifiable(sans.names),
      sha1Hex: sha1.convert(der).toString(),
      sha256Hex: sha256.convert(der).toString(),
      publicKeyAlgorithm: key.$1,
      publicKeyBits: key.$2,
      der: Uint8List.fromList(der),
      pem: _canonicalPem(der),
      subjectDer: subjectDer,
      issuerDer: issuerDer,
    );
  }

  static String _parseName(_DerNode name, Uint8List bytes) {
    _expect(name, 0x30);
    final List<String> rdns = <String>[];
    for (final _DerNode set in name.children) {
      _expect(set, 0x31, children: 1);
      final List<String> attributes = <String>[];
      for (final _DerNode attribute in set.children) {
        _expect(attribute, 0x30, exactChildren: 2);
        final String oid = _oid(attribute.children[0], bytes);
        final String value = _string(
          attribute.children[1],
          bytes,
        ).replaceAll(r'\', r'\\').replaceAll(',', r'\,').replaceAll('+', r'\+');
        attributes.add('${_dnNames[oid] ?? oid}=$value');
      }
      rdns.add(attributes.join('+'));
    }
    if (rdns.isEmpty) return '(empty name)';
    return rdns.join(', ');
  }

  static (String, int?) _parsePublicKey(_DerNode spki) {
    _expect(spki, 0x30, exactChildren: 2);
    _validateBitString(spki.children[1], spki.source);
    final _DerNode algorithm = spki.children[0];
    _expect(algorithm, 0x30, children: 1, maxChildren: 2);
    final Uint8List bytes = spki.source;
    final String oid = _oid(algorithm.children[0], bytes);
    if (oid == '1.2.840.113549.1.1.1') {
      if (algorithm.children.length == 2) {
        final _DerNode parameter = algorithm.children[1];
        if (parameter.tag != 0x05 || parameter.value(bytes).isNotEmpty) {
          throw const FormatException();
        }
      }
      final Uint8List bitString = _bitString(spki.children[1], bytes);
      final _DerNode rsa = _DerParser(
        bitString,
        budget: spki.budget,
        baseDepth: spki.depth + 1,
      ).parseRoot();
      _expect(rsa, 0x30, exactChildren: 2);
      final int bits = _integerBits(rsa.children[0], rsa.source);
      final int exponent = _smallPositiveInteger(rsa.children[1], rsa.source);
      if (exponent < 3 || exponent.isEven) throw const FormatException();
      return ('RSA', bits);
    }
    if (oid == '1.2.840.10045.2.1') {
      if (algorithm.children.length != 2) throw const FormatException();
      final String? curve = algorithm.children.length > 1
          ? _oid(algorithm.children[1], bytes)
          : null;
      final (String, int)? known = curve == null ? null : _curves[curve];
      final Uint8List point = _bitString(spki.children[1], bytes);
      if (point.isEmpty ||
          (point.first != 0x02 && point.first != 0x03 && point.first != 0x04)) {
        throw const FormatException();
      }
      if (known != null &&
          !((point.first == 0x04 &&
                  point.length == 1 + 2 * ((known.$2 + 7) ~/ 8)) ||
              ((point.first == 0x02 || point.first == 0x03) &&
                  point.length == 1 + ((known.$2 + 7) ~/ 8)))) {
        throw const FormatException();
      }
      return (known?.$1 ?? 'EC${curve == null ? '' : ' ($curve)'}', known?.$2);
    }
    if (oid == '1.3.101.112') {
      if (algorithm.children.length != 1) throw const FormatException();
      if (_bitString(spki.children[1], bytes).length != 32) {
        throw const FormatException();
      }
      return ('Ed25519', 256);
    }
    if (oid == '1.3.101.113') {
      if (algorithm.children.length != 1) throw const FormatException();
      if (_bitString(spki.children[1], bytes).length != 57) {
        throw const FormatException();
      }
      return ('Ed448', 448);
    }
    if (oid == '1.2.840.10040.4.1') {
      final _DerNode? params = algorithm.children.length > 1
          ? algorithm.children[1]
          : null;
      if (params != null) {
        _expect(params, 0x30, exactChildren: 3);
        for (final _DerNode parameter in params.children) {
          _integerBits(parameter, bytes);
        }
      }
      final Uint8List keyBytes = _bitString(spki.children[1], bytes);
      final _DerNode keyNode = _DerParser(
        keyBytes,
        budget: spki.budget,
        baseDepth: spki.depth + 1,
      ).parseRoot();
      _integerBits(keyNode, keyNode.source);
      return (
        'DSA',
        params != null && params.tag == 0x30 && params.children.isNotEmpty
            ? _integerBits(params.children[0], bytes)
            : null,
      );
    }
    return ('OID $oid', null);
  }

  static ({List<String> names, bool critical}) _parseSans(
    Iterable<_DerNode> optionalFields,
    Uint8List certificateBytes,
  ) {
    final _DerNode? wrapper = optionalFields
        .where((n) => n.tag == 0xa3)
        .firstOrNull;
    if (wrapper == null) return (names: const <String>[], critical: false);
    if (wrapper.children.length != 1) throw const FormatException();
    final _DerNode extensions = wrapper.children.single;
    _expect(extensions, 0x30, children: 1);
    List<String>? result;
    bool sanCritical = false;
    final Set<String> seen = <String>{};
    for (final _DerNode extension in extensions.children) {
      _expect(extension, 0x30, children: 2, maxChildren: 3);
      final String oid = _oid(extension.children[0], certificateBytes);
      if (!seen.add(oid)) throw const FormatException();
      final bool criticalValue = extension.children.length == 3;
      if (extension.children.length == 3) {
        final _DerNode critical = extension.children[1];
        final Uint8List value = critical.value(certificateBytes);
        if (critical.tag != 0x01 || value.length != 1 || value.single != 0xff) {
          throw const FormatException();
        }
      }
      final _DerNode value = extension.children.last;
      if (value.tag != 0x04) throw const FormatException();
      if (oid != '2.5.29.17') {
        continue;
      }
      if (result != null) throw const FormatException();
      sanCritical = criticalValue;
      final _DerNode names = _DerParser(
        value.value(certificateBytes),
        budget: extension.budget,
        baseDepth: value.depth + 1,
      ).parseRoot();
      _expect(names, 0x30);
      if (names.children.isEmpty || names.children.length > maxSans) {
        throw const FormatException();
      }
      result = <String>[
        for (final _DerNode name in names.children)
          _generalName(name, names.source),
      ];
    }
    return (names: result ?? const <String>[], critical: sanCritical);
  }

  static void _validateOptionalFields(
    List<_DerNode> fields,
    int version,
    Uint8List bytes,
  ) {
    int previousOrder = 0;
    for (final _DerNode field in fields) {
      final int order = switch (field.tag) {
        0x81 => 1,
        0x82 => 2,
        0xa3 => 3,
        _ => throw const FormatException(),
      };
      if (order <= previousOrder) {
        throw const FormatException();
      }
      previousOrder = order;
      if (field.tag == 0x81 || field.tag == 0x82) {
        if (version < 1) throw const FormatException();
        final Uint8List value = field.value(bytes);
        if (value.isEmpty || value.first > 7) throw const FormatException();
        if (value.length == 1 && value.first != 0) {
          throw const FormatException();
        }
        if (value.length > 1 &&
            value.first != 0 &&
            value.last & ((1 << value.first) - 1) != 0) {
          throw const FormatException();
        }
      } else if (version != 2) {
        throw const FormatException();
      }
    }
  }

  static String _generalName(_DerNode node, Uint8List bytes) {
    final Uint8List value = node.value(bytes);
    if (value.length > maxTextBytes) throw const FormatException();
    return switch (node.tag) {
      0x81 => 'email:${_ascii(value)}',
      0x82 => 'DNS:${_ascii(value)}',
      0x86 => 'URI:${_ascii(value)}',
      0x87 => 'IP:${_ip(value)}',
      _ => 'other:${node.tag.toRadixString(16)}',
    };
  }

  static String _ip(Uint8List value) {
    if (value.length == 4) return value.join('.');
    if (value.length != 16) throw const FormatException();
    return <String>[
      for (int i = 0; i < 16; i += 2)
        ((value[i] << 8) | value[i + 1]).toRadixString(16),
    ].join(':');
  }

  static DateTime _parseTime(_DerNode node, Uint8List bytes) {
    final String value = _ascii(node.value(bytes));
    final RegExp pattern;
    final int year;
    if (node.tag == 0x17) {
      pattern = RegExp(r'^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$');
      final RegExpMatch? match = pattern.firstMatch(value);
      if (match == null) throw const FormatException();
      final int shortYear = int.parse(match.group(1)!);
      year = shortYear >= 50 ? 1900 + shortYear : 2000 + shortYear;
      return _checkedUtc(year, match);
    }
    if (node.tag == 0x18) {
      pattern = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$');
      final RegExpMatch? match = pattern.firstMatch(value);
      if (match == null) throw const FormatException();
      year = int.parse(match.group(1)!);
      if (year < 2050) throw const FormatException();
      return _checkedUtc(year, match);
    }
    throw const FormatException();
  }

  static DateTime _checkedUtc(int year, RegExpMatch match) {
    final List<int> parts = <int>[
      for (int i = 2; i <= 6; i++) int.parse(match.group(i)!),
    ];
    final DateTime value = DateTime.utc(
      year,
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
    );
    if (value.year != year ||
        value.month != parts[0] ||
        value.day != parts[1] ||
        value.hour != parts[2] ||
        value.minute != parts[3] ||
        value.second != parts[4]) {
      throw const FormatException();
    }
    return value;
  }

  static String _oid(_DerNode node, Uint8List bytes) {
    if (node.tag != 0x06) throw const FormatException();
    final Uint8List value = node.value(bytes);
    if (value.isEmpty || value.length > 128) throw const FormatException();
    final List<int> subidentifiers = <int>[];
    int arc = 0;
    bool open = false;
    bool firstByte = true;
    for (final int byte in value) {
      if (firstByte && byte == 0x80) throw const FormatException();
      if (arc > 0x0fffffff) throw const FormatException();
      arc = (arc << 7) | (byte & 0x7f);
      if (arc > 0x0fffffff) throw const FormatException();
      open = byte & 0x80 != 0;
      if (!open) {
        subidentifiers.add(arc);
        arc = 0;
        firstByte = true;
      } else {
        firstByte = false;
      }
    }
    if (open || subidentifiers.isEmpty) throw const FormatException();
    final int combined = subidentifiers.first;
    final int first = combined < 40
        ? 0
        : combined < 80
        ? 1
        : 2;
    final List<int> arcs = <int>[
      first,
      combined - first * 40,
      ...subidentifiers.skip(1),
    ];
    return arcs.join('.');
  }

  static String _string(_DerNode node, Uint8List bytes) {
    final Uint8List value = node.value(bytes);
    if (value.length > maxTextBytes) throw const FormatException();
    return switch (node.tag) {
      0x0c => _safeText(utf8.decode(value)),
      0x13 || 0x14 || 0x16 => _ascii(value),
      0x1e => _bmp(value),
      _ => throw const FormatException(),
    };
  }

  static String _ascii(Uint8List value) {
    if (value.any((int byte) => byte < 0x20 || byte >= 0x7f)) {
      throw const FormatException();
    }
    return ascii.decode(value);
  }

  static String _bmp(Uint8List value) {
    if (value.length.isOdd) throw const FormatException();
    final List<int> codeUnits = <int>[
      for (int i = 0; i < value.length; i += 2) (value[i] << 8) | value[i + 1],
    ];
    if (codeUnits.any(
      (int unit) =>
          unit < 0x20 || unit == 0x7f || (unit >= 0xd800 && unit <= 0xdfff),
    )) {
      throw const FormatException();
    }
    return _safeText(String.fromCharCodes(codeUnits));
  }

  static int _integerBits(_DerNode node, Uint8List bytes) {
    if (node.tag != 0x02) throw const FormatException();
    final Uint8List value = node.value(bytes);
    if (value.isEmpty ||
        value[0] & 0x80 != 0 ||
        (value.length > 1 && value[0] == 0 && value[1] & 0x80 == 0)) {
      throw const FormatException();
    }
    int start = value[0] == 0 ? 1 : 0;
    if (start == value.length) throw const FormatException();
    final int first = value[start];
    final int bits = (value.length - start) * 8 - (8 - first.bitLength);
    if (bits == 0) throw const FormatException();
    return bits;
  }

  static int _smallPositiveInteger(_DerNode node, Uint8List bytes) {
    _integerBits(node, bytes);
    final Uint8List value = node.value(bytes);
    final int start = value.first == 0 ? 1 : 0;
    if (value.length - start > 8) throw const FormatException();
    int result = 0;
    for (final int byte in value.skip(start)) {
      result = (result << 8) | byte;
    }
    return result;
  }

  static int _smallNonnegativeInteger(_DerNode node, Uint8List bytes) {
    if (node.tag != 0x02) throw const FormatException();
    final Uint8List value = node.value(bytes);
    if (value.isEmpty ||
        value[0] & 0x80 != 0 ||
        (value.length > 1 && value[0] == 0 && value[1] & 0x80 == 0) ||
        value.length > 8) {
      throw const FormatException();
    }
    int result = 0;
    for (final int byte in value) {
      result = (result << 8) | byte;
    }
    return result;
  }

  static String _safeText(String value) {
    if (value.runes.any(
      (int rune) =>
          rune < 0x20 || rune == 0x7f || (rune >= 0xd800 && rune <= 0xdfff),
    )) {
      throw const FormatException();
    }
    return value;
  }

  static String _canonicalPem(Uint8List der) {
    final String body = base64Encode(der);
    final String lines = <String>[
      for (int i = 0; i < body.length; i += 64)
        body.substring(i, (i + 64).clamp(0, body.length)),
    ].join('\n');
    return '-----BEGIN CERTIFICATE-----\n$lines\n-----END CERTIFICATE-----';
  }

  static Uint8List _bitString(_DerNode node, Uint8List bytes) {
    _validateBitString(node, bytes);
    return Uint8List.sublistView(node.value(bytes), 1);
  }

  static void _validateAlgorithmIdentifier(_DerNode node, Uint8List bytes) {
    _expect(node, 0x30, children: 1, maxChildren: 2);
    _oid(node.children.first, bytes);
  }

  static void _validateBitString(_DerNode node, Uint8List bytes) {
    final Uint8List value = node.value(bytes);
    if (node.tag != 0x03 || value.isEmpty || value[0] > 7) {
      throw const FormatException();
    }
    if (value.length == 1 && value[0] != 0) throw const FormatException();
    if (value.length > 1 &&
        value[0] != 0 &&
        value.last & ((1 << value[0]) - 1) != 0) {
      throw const FormatException();
    }
  }

  static void _expect(
    _DerNode node,
    int tag, {
    int children = 0,
    int? exactChildren,
    int? maxChildren,
  }) {
    if (node.tag != tag ||
        node.children.length < children ||
        (exactChildren != null && node.children.length != exactChildren) ||
        (maxChildren != null && node.children.length > maxChildren)) {
      throw const FormatException();
    }
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _DerNode {
  const _DerNode({
    required this.tag,
    required this.start,
    required this.valueStart,
    required this.end,
    required this.children,
    required this.source,
    required this.budget,
    required this.depth,
  });

  final int tag;
  final int start;
  final int valueStart;
  final int end;
  final List<_DerNode> children;
  final Uint8List source;
  final _DerBudget budget;
  final int depth;

  Uint8List value(Uint8List bytes) =>
      Uint8List.sublistView(bytes, valueStart, end);
  Uint8List encoded(Uint8List bytes) =>
      Uint8List.fromList(bytes.sublist(start, end));
}

class _DerParser {
  _DerParser(this.bytes, {_DerBudget? budget, this.baseDepth = 0})
    : budget = budget ?? _DerBudget();

  final Uint8List bytes;
  final _DerBudget budget;
  final int baseDepth;

  _DerNode parseRoot() {
    final (_DerNode, int) result = _parse(0, bytes.length, baseDepth);
    if (result.$2 != bytes.length) throw const FormatException();
    return result.$1;
  }

  (_DerNode, int) _parse(int offset, int limit, int depth) {
    if (++budget.nodes > X509Inspector.maxNodes ||
        depth > X509Inspector.maxDepth) {
      throw const FormatException();
    }
    if (offset + 2 > limit) throw const FormatException();
    final int start = offset;
    final int tag = bytes[offset++];
    if (tag == 0 || tag & 0x1f == 0x1f) throw const FormatException();
    final int firstLength = bytes[offset++];
    int length;
    if (firstLength & 0x80 == 0) {
      length = firstLength;
    } else {
      final int count = firstLength & 0x7f;
      if (count == 0 ||
          count > 4 ||
          offset + count > limit ||
          bytes[offset] == 0) {
        throw const FormatException();
      }
      length = 0;
      for (int i = 0; i < count; i++) {
        length = (length << 8) | bytes[offset++];
      }
      if (length < 128) throw const FormatException();
    }
    final int valueStart = offset;
    final int end = valueStart + length;
    if (end < valueStart || end > limit) throw const FormatException();
    final List<_DerNode> children = <_DerNode>[];
    if (tag & 0x20 != 0) {
      while (offset < end) {
        final (_DerNode, int) child = _parse(offset, end, depth + 1);
        children.add(child.$1);
        offset = child.$2;
      }
      if (offset != end) throw const FormatException();
    }
    return (
      _DerNode(
        tag: tag,
        start: start,
        valueStart: valueStart,
        end: end,
        children: List<_DerNode>.unmodifiable(children),
        source: bytes,
        budget: budget,
        depth: depth,
      ),
      end,
    );
  }
}

class _DerBudget {
  int nodes = 0;
}

const Map<String, String> _dnNames = <String, String>{
  '2.5.4.3': 'CN',
  '2.5.4.5': 'serialNumber',
  '2.5.4.6': 'C',
  '2.5.4.7': 'L',
  '2.5.4.8': 'ST',
  '2.5.4.9': 'street',
  '2.5.4.10': 'O',
  '2.5.4.11': 'OU',
  '1.2.840.113549.1.9.1': 'emailAddress',
};

const Map<String, (String, int)> _curves = <String, (String, int)>{
  '1.2.840.10045.3.1.7': ('EC P-256', 256),
  '1.3.132.0.34': ('EC P-384', 384),
  '1.3.132.0.35': ('EC P-521', 521),
  '1.3.132.0.10': ('EC secp256k1', 256),
};
