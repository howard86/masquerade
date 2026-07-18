import '../utils/sensitive_data_policy.dart';
import 'content_type.dart';

/// A detected value's specific shape, separate from its generic routing type.
enum ArtifactKind {
  uuid,
  ip,
  number,
  timestamp,
  cron,
  json,
  yaml,
  toml,
  jwt,
  base64,
  url,
  color,
  math,
  bps,
  bytes,
  list,
  hash,
  unknown,
}

enum ArtifactProvenance {
  typed,
  clipboard,
  camera,
  liveLink,
  generated,
  shareExtension,
  fileImport,
  qrImageImport,
}

enum ArtifactSensitivity { standard, sensitive }

/// Parsed technical data that can be routed independently of a destination.
class Artifact<T> {
  Artifact({
    required this.kind,
    required this.rawValue,
    required this.provenance,
    this.parserResult,
    ArtifactSensitivity sensitivity = ArtifactSensitivity.standard,
    int previewLength = 80,
  }) : _declaredSensitivity = sensitivity,
       _previewLength = previewLength {
    if (previewLength <= 0) {
      throw ArgumentError.value(previewLength, 'previewLength', 'must be > 0');
    }
  }

  final ArtifactKind kind;
  final String rawValue;
  final ArtifactProvenance provenance;

  /// The parser's original result, retained so later routing need not reparse.
  final T? parserResult;

  final ArtifactSensitivity _declaredSensitivity;
  final int _previewLength;

  ContentType get contentType => switch (kind) {
    ArtifactKind.number ||
    ArtifactKind.math ||
    ArtifactKind.bps => ContentType.number,
    ArtifactKind.timestamp => ContentType.epoch,
    ArtifactKind.json ||
    ArtifactKind.yaml ||
    ArtifactKind.toml => ContentType.json,
    ArtifactKind.bytes => ContentType.bytes,
    ArtifactKind.list => ContentType.lines,
    ArtifactKind.color => ContentType.color,
    ArtifactKind.uuid ||
    ArtifactKind.ip ||
    ArtifactKind.cron ||
    ArtifactKind.jwt ||
    ArtifactKind.base64 ||
    ArtifactKind.url ||
    ArtifactKind.hash ||
    ArtifactKind.unknown => ContentType.text,
  };

  bool get isSensitive =>
      _declaredSensitivity == ArtifactSensitivity.sensitive ||
      SensitiveDataPolicy.protects(
        utilityId: switch (kind) {
          ArtifactKind.jwt => 'jwt',
          ArtifactKind.base64 => 'base64',
          ArtifactKind.bytes => 'bytes',
          ArtifactKind.url => 'url',
          _ => null,
        },
        values: <String>[rawValue],
      );

  ArtifactSensitivity get sensitivity => isSensitive
      ? ArtifactSensitivity.sensitive
      : ArtifactSensitivity.standard;

  /// A bounded display value that never echoes sensitive input.
  String get safePreview {
    if (isSensitive && rawValue == SensitiveDataPolicy.mask) return '[hidden]';
    return SensitiveDataPolicy.safePreview(
      rawValue,
      max: _previewLength,
      sensitive: isSensitive,
    );
  }
}

/// Ranked evidence that one artifact can be handled by one or more tools.
class DetectionMatch<T> {
  DetectionMatch({
    required this.artifact,
    required this.confidence,
    required this.reason,
    required this.primaryToolId,
    required Set<String> compatibleToolIds,
  }) : compatibleToolIds = Set<String>.unmodifiable(compatibleToolIds) {
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be 0 through 1',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    }
    if (compatibleToolIds.isEmpty) {
      throw ArgumentError.value(
        compatibleToolIds,
        'compatibleToolIds',
        'must not be empty',
      );
    }
    if (!compatibleToolIds.contains(primaryToolId)) {
      throw ArgumentError.value(
        primaryToolId,
        'primaryToolId',
        'must be compatible',
      );
    }
  }

  final Artifact<T> artifact;
  final double confidence;
  final String reason;
  final String primaryToolId;
  final Set<String> compatibleToolIds;
}
