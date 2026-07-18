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

  static bool isSensitiveTool(String? utilityId) =>
      utilityId == 'jwt' ||
      utilityId == 'generator' ||
      utilityId == 'artifact_inspector';

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
