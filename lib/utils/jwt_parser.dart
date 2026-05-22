import 'dart:convert';

sealed class JwtParseResult {}

class JwtOk extends JwtParseResult {
  JwtOk({
    required this.header,
    required this.payload,
    required this.signature,
    this.expiresAt,
    this.notBefore,
    this.issuedAt,
    DateTime? now,
  }) : _now = now ?? DateTime.now().toUtc();

  final Map<String, dynamic> header;
  final Map<String, dynamic> payload;
  final String signature;
  final DateTime? expiresAt;
  final DateTime? notBefore;
  final DateTime? issuedAt;
  final DateTime _now;

  bool get isExpired => expiresAt != null && _now.isAfter(expiresAt!);
  bool get isNotYetValid => notBefore != null && _now.isBefore(notBefore!);
}

class JwtErr extends JwtParseResult {
  JwtErr(this.message);
  final String message;
}

class JwtParser {
  const JwtParser._();

  static JwtParseResult parse(String input, {DateTime? now}) {
    final String trimmed = input.trim();
    final List<String> parts = trimmed.split('.');
    if (parts.length != 3) {
      return JwtErr('JWT must have exactly 3 segments');
    }

    final Map<String, dynamic>? header = _decodeSegment(parts[0]);
    if (header == null) return JwtErr('Invalid header segment');

    final Map<String, dynamic>? payload = _decodeSegment(parts[1]);
    if (payload == null) return JwtErr('Invalid payload segment');

    return JwtOk(
      header: header,
      payload: payload,
      signature: parts[2],
      expiresAt: _epochToDateTime(payload['exp']),
      notBefore: _epochToDateTime(payload['nbf']),
      issuedAt: _epochToDateTime(payload['iat']),
      now: now,
    );
  }

  static Map<String, dynamic>? _decodeSegment(String seg) {
    try {
      final String json = _b64urlDecode(seg);
      final dynamic decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _b64urlDecode(String seg) {
    String s = seg.replaceAll('-', '+').replaceAll('_', '/');
    final int rem = s.length % 4;
    if (rem != 0) s = s.padRight(s.length + (4 - rem), '=');
    return utf8.decode(base64Decode(s));
  }

  static DateTime? _epochToDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    return null;
  }
}
