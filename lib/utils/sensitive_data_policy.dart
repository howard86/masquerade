import 'dart:convert';

import 'bytes_parser.dart';
import 'text_truncate.dart';

/// One boundary for deciding whether content may leave its visible source.
abstract final class SensitiveDataPolicy {
  static const String mask = '••••';
  static const int _maxReversibleInspectionLength = 65536;

  static final RegExp _credentialKey = RegExp(
    r'''(?:^|[\[\{,?&;])\s*(?:-\s*)?["']?(?:[A-Za-z0-9]+[-_.])*(?:access[-_.]?key(?:[-_.]?id)?|access[-_.]?token|api[-_.]?key|auth[-_.]?token|authorization|client[-_.]?secret|consumer[-_.]?secret|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|proxy[-_.]?authorization|pwd|refresh[-_.]?token|secret[-_.]?access[-_.]?key|secret(?:[-_.]?key)?|session[-_.]?token|token)["']?\s*[:=]''',
    caseSensitive: false,
    multiLine: true,
  );
  // key=value is also valid TOML; without source-format metadata, fail closed.
  static final RegExp _environmentEntry = RegExp(
    r'^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*\S',
    multiLine: true,
  );
  static final RegExp _privateKey = RegExp(
    r'-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----',
  );
  static final RegExp _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*',
  );
  static final RegExp _secretKey = RegExp(
    r'^(?:.*[-_.])?(?:access[-_.]?token|api[-_.]?key|auth[-_.]?token|authorization|client[-_.]?secret|consumer[-_.]?secret|cookie|credential(?:s)?|database[-_.]?url|pass(?:word|wd)?|private[-_.]?key|proxy[-_.]?authorization|pwd|redis[-_.]?url|refresh[-_.]?token|secret[-_.]?access[-_.]?key|secret(?:[-_.]?key)?|session[-_.]?token|set[-_.]?cookie|signing[-_.]?key|token)$',
    caseSensitive: false,
  );
  static final RegExp _secretValue = RegExp(
    r'''(?:^|\s)(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+|\b[A-Za-z][A-Za-z0-9+.-]*://[^\s/:@]+:[^\s/@]+@[^\s]+|\b(?:AKIA|ASIA)[A-Z0-9]{16}\b|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk_(?:live|test)_[A-Za-z0-9]{12,})\b''',
    caseSensitive: false,
  );

  static bool isSensitiveTool(String? utilityId) =>
      utilityId == 'jwt' ||
      utilityId == 'generator' ||
      utilityId == 'http_inspector' ||
      utilityId == 'log_stack_inspector' ||
      utilityId == 'environment_config_inspector' ||
      utilityId == 'unicode_string_inspector' ||
      utilityId == 'artifact_inspector' ||
      utilityId == 'x509_inspector';

  static bool isCredentialKey(String key) => _secretKey.hasMatch(key.trim());

  /// Checks a scalar without treating ordinary `KEY=value` config as secret.
  /// Reversible encodings are inspected once so encoded credentials cannot
  /// bypass redacted config exports.
  static bool containsSecretLikeValue(String value) =>
      _containsSecretLikeValue(value, inspectEncoding: true);

  static bool _containsSecretLikeValue(
    String value, {
    required bool inspectEncoding,
  }) {
    if (_privateKey.hasMatch(value) ||
        _jwt.hasMatch(value) ||
        _secretValue.hasMatch(value)) {
      return true;
    }
    if (!inspectEncoding) {
      return false;
    }
    final bool percentEncoded = RegExp(r'%(?:[0-9A-Fa-f]{2})').hasMatch(value);
    final String compact = value.trim();
    final bool base64Shaped =
        compact.length >= 8 &&
        RegExp(r'^[A-Za-z0-9_+/-]+={0,2}$').hasMatch(compact);
    if (value.length > _maxReversibleInspectionLength) {
      return percentEncoded || base64Shaped;
    }
    final List<String> decoded = <String>[];
    if (percentEncoded) {
      try {
        decoded.add(Uri.decodeComponent(value));
      } catch (_) {
        // Invalid percent input is not reversible and cannot reveal a secret.
      }
    }
    if (base64Shaped) {
      try {
        decoded.add(utf8.decode(base64.decode(_paddedBase64(compact))));
      } catch (_) {
        // Not printable UTF-8 base64.
      }
    }
    return decoded.any(
      (String candidate) =>
          containsSensitiveArtifact(candidate) ||
          _containsSecretLikeValue(candidate, inspectEncoding: false),
    );
  }

  static String redactedConfigValue(String key, String value) =>
      isCredentialKey(key) || containsSecretLikeValue(value) ? mask : value;

  static bool containsSensitiveArtifact(String value) =>
      _credentialKey.hasMatch(value) ||
      _environmentEntry.hasMatch(value) ||
      _privateKey.hasMatch(value) ||
      _jwt.hasMatch(value);

  static bool _containsProtectedToolValue(String value, String? utilityId) {
    final bool direct = containsSensitiveArtifact(value);
    if (utilityId != 'base64' && utilityId != 'bytes' && utilityId != 'url') {
      return direct;
    }
    if (value.length > _maxReversibleInspectionLength) return true;
    try {
      final String decoded = switch (utilityId) {
        'base64' => utf8.decode(base64.decode(_paddedBase64(value))),
        'bytes' => switch (BytesParser.parse(value)) {
          BytesParseOk(:final bytes) => utf8.decode(bytes),
          BytesParseError() => '',
        },
        'url' => Uri.decodeComponent(value),
        _ => '',
      };
      // Base64 padding resembles an environment assignment (for example,
      // `aGVsbG8=`). A successful safe decode distinguishes that ordinary seed.
      return containsSensitiveArtifact(decoded) ||
          (utilityId != 'base64' && direct);
    } catch (_) {
      return direct;
    }
  }

  static String _paddedBase64(String value) {
    String normalized = value.trim().replaceAll('-', '+').replaceAll('_', '/');
    final int remainder = normalized.length % 4;
    if (remainder == 1) throw const FormatException('Invalid base64 length');
    if (remainder > 0) normalized += '=' * (4 - remainder);
    return normalized;
  }

  static bool protects({
    String? utilityId,
    bool sensitive = false,
    Iterable<String> values = const <String>[],
  }) =>
      sensitive ||
      isSensitiveTool(utilityId) ||
      values.any(
        (String value) => _containsProtectedToolValue(value, utilityId),
      );

  /// Returns null when [value] must not enter serialized state.
  static String? persistedValue(
    String? value, {
    String? utilityId,
    bool sensitive = false,
  }) {
    if (value == null ||
        protects(
          utilityId: utilityId,
          sensitive: sensitive,
          values: <String>[value],
        )) {
      return null;
    }
    return value;
  }

  /// Produces a bounded preview without ever echoing a protected value.
  static String safePreview(
    String value, {
    required int max,
    String? utilityId,
    bool sensitive = false,
  }) =>
      protects(
        utilityId: utilityId,
        sensitive: sensitive,
        values: <String>[value],
      )
      ? mask
      : truncateWithEllipsis(value, max: max);
}
