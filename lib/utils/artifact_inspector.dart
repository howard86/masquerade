import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/artifact.dart';
import '../utility_catalog.dart';
import 'encoding_parser.dart';
import 'json_parser.dart';
import 'jwt_parser.dart';
import 'sensitive_data_policy.dart';
import 'toml_parser.dart';
import 'yaml_parser.dart';

enum InspectorLayerType { input, detection, transform }

class InspectorLayer {
  const InspectorLayer({
    required this.type,
    required this.label,
    required this.artifact,
    required this.children,
    this.confidence,
    this.evidence,
    this.warning,
    this.primaryToolId,
  });

  final InspectorLayerType type;
  final String label;
  final Artifact<Object?> artifact;
  final List<InspectorLayer> children;
  final double? confidence;
  final String? evidence;
  final String? warning;
  final String? primaryToolId;

  bool get isSensitive => artifact.isSensitive;
  String get safePreview => artifact.safePreview;
}

class ArtifactInspection {
  const ArtifactInspection({
    required this.root,
    required this.nodeCount,
    required this.truncated,
    this.error,
  });

  final InspectorLayer? root;
  final int nodeCount;
  final bool truncated;
  final String? error;

  bool get isSuccess => root != null && error == null;
}

/// Recursively explains values using the catalog's typed detectors.
class ArtifactInspector {
  const ArtifactInspector._();

  static const int maxTextBytes = 64 * 1024;
  static const int maxDepth = 12;
  static const int maxNodes = 48;
  static const int maxChildren = 8;

  static ArtifactInspection inspect(
    String input, {
    ArtifactProvenance provenance = ArtifactProvenance.typed,
    bool inheritedSensitive = false,
  }) {
    final _InspectionBuilder builder = _InspectionBuilder(
      provenance,
      inheritedSensitive,
    );
    return builder.inspect(input);
  }
}

class _InspectionBuilder {
  _InspectionBuilder(this.provenance, this.inheritedSensitive);

  final ArtifactProvenance provenance;
  final bool inheritedSensitive;
  final Set<String> _seenDigests = <String>{};
  int _nodes = 0;
  bool _truncated = false;

  ArtifactInspection inspect(String input) {
    if (!_withinLimit(input)) {
      return const ArtifactInspection(
        root: null,
        nodeCount: 0,
        truncated: true,
        error: 'Input exceeds the 64 KiB inspection limit.',
      );
    }
    if (input.trim().isEmpty) {
      return const ArtifactInspection(
        root: null,
        nodeCount: 0,
        truncated: false,
        error: 'Enter an artifact to inspect.',
      );
    }

    final List<DetectionMatch<Object?>> matches = _safeDetect(input);
    final bool sensitive =
        inheritedSensitive ||
        SensitiveDataPolicy.containsSensitiveArtifact(input) ||
        matches.any(
          (DetectionMatch<Object?> match) => match.artifact.isSensitive,
        );
    _seenDigests.add(_digest('input', input));
    _nodes = 1;
    final Artifact<Object?> artifact = Artifact<Object?>(
      kind: matches.isEmpty
          ? ArtifactKind.unknown
          : matches.first.artifact.kind,
      rawValue: input,
      provenance: provenance,
      sensitivity: sensitive
          ? ArtifactSensitivity.sensitive
          : ArtifactSensitivity.standard,
    );
    final List<InspectorLayer> children = _detections(
      matches,
      depth: 1,
      inheritedSensitive: sensitive,
    );
    final InspectorLayer root = InspectorLayer(
      type: InspectorLayerType.input,
      label: 'Input',
      artifact: artifact,
      evidence: sensitive ? 'Protected input.' : 'Original input.',
      warning: sensitive
          ? 'Sensitive content hidden.'
          : matches.isEmpty
          ? 'No typed artifact detected.'
          : null,
      children: children,
    );
    return ArtifactInspection(
      root: root,
      nodeCount: _nodes,
      truncated: _truncated,
    );
  }

  List<InspectorLayer> _detections(
    List<DetectionMatch<Object?>> matches, {
    required int depth,
    required bool inheritedSensitive,
  }) {
    if (depth > ArtifactInspector.maxDepth) {
      _truncated = true;
      return const <InspectorLayer>[];
    }
    final List<InspectorLayer> layers = <InspectorLayer>[];
    for (final DetectionMatch<Object?> match in matches.take(
      ArtifactInspector.maxChildren,
    )) {
      if (!_reserveNode()) break;
      final bool sensitive = inheritedSensitive || match.artifact.isSensitive;
      final Artifact<Object?> artifact = _withSensitivity(
        match.artifact,
        sensitive,
      );
      layers.add(
        InspectorLayer(
          type: InspectorLayerType.detection,
          label: _kindLabel(artifact.kind),
          artifact: artifact,
          confidence: match.confidence,
          evidence: sensitive
              ? 'Protected typed detector match.'
              : match.reason,
          primaryToolId: match.primaryToolId,
          children: _transforms(
            match,
            depth: depth + 1,
            inheritedSensitive: sensitive,
          ),
        ),
      );
    }
    if (matches.length > ArtifactInspector.maxChildren) _truncated = true;
    return List<InspectorLayer>.unmodifiable(layers);
  }

  List<InspectorLayer> _transforms(
    DetectionMatch<Object?> match, {
    required int depth,
    required bool inheritedSensitive,
  }) {
    if (depth > ArtifactInspector.maxDepth) {
      _truncated = true;
      return const <InspectorLayer>[];
    }
    final List<_DerivedValue> values;
    try {
      values = _derive(match);
    } catch (_) {
      return const <InspectorLayer>[];
    }
    final List<InspectorLayer> layers = <InspectorLayer>[];
    for (final _DerivedValue value in values.take(
      ArtifactInspector.maxChildren,
    )) {
      if (!_reserveNode()) break;
      final bool oversized = !_withinLimit(value.text);
      final String digest = oversized ? '' : _digest(value.typeKey, value.text);
      final bool repeated = !oversized && !_seenDigests.add(digest);
      final List<DetectionMatch<Object?>> matches = oversized || repeated
          ? const <DetectionMatch<Object?>>[]
          : _safeDetect(value.text);
      final bool sensitive =
          inheritedSensitive ||
          SensitiveDataPolicy.containsSensitiveArtifact(value.text) ||
          matches.any(
            (DetectionMatch<Object?> candidate) =>
                candidate.artifact.isSensitive,
          );
      final Artifact<Object?> artifact = Artifact<Object?>(
        kind: matches.isEmpty
            ? ArtifactKind.unknown
            : matches.first.artifact.kind,
        rawValue: value.text,
        provenance: provenance,
        sensitivity: sensitive
            ? ArtifactSensitivity.sensitive
            : ArtifactSensitivity.standard,
      );
      final String? warning = oversized
          ? 'Derived value exceeds the 64 KiB inspection limit.'
          : repeated
          ? 'Repeated normalized value; recursion stopped.'
          : matches.isEmpty
          ? 'No deeper typed artifact detected.'
          : null;
      layers.add(
        InspectorLayer(
          type: InspectorLayerType.transform,
          label: sensitive ? value.protectedLabel : value.label,
          artifact: artifact,
          evidence: sensitive ? 'Protected derived value.' : value.evidence,
          warning: warning,
          children: oversized || repeated
              ? const <InspectorLayer>[]
              : _detections(
                  matches,
                  depth: depth + 1,
                  inheritedSensitive: sensitive,
                ),
        ),
      );
    }
    if (values.length > ArtifactInspector.maxChildren) _truncated = true;
    return List<InspectorLayer>.unmodifiable(layers);
  }

  List<_DerivedValue> _derive(DetectionMatch<Object?> match) {
    final Object? parsed = match.artifact.parserResult;
    switch (match.artifact.kind) {
      case ArtifactKind.url:
        return _urlValues(match.artifact.rawValue);
      case ArtifactKind.jwt:
        if (parsed is JwtOk) {
          return <_DerivedValue>[
            if (_structuredText(parsed.header) case final String text)
              _DerivedValue.json('JWT header JSON', text),
            if (_structuredText(parsed.payload) case final String text)
              _DerivedValue.json('JWT payload JSON', text),
          ];
        }
      case ArtifactKind.base64:
        if (parsed is EncodingResult && parsed.result != null) {
          return <_DerivedValue>[
            _DerivedValue(
              label: 'UTF-8 text',
              protectedLabel: 'UTF-8 text',
              evidence: 'Decoded strict printable UTF-8 text.',
              typeKey: 'string',
              text: parsed.result!,
            ),
          ];
        }
      case ArtifactKind.json:
        if (parsed is JSONOk) return _structuredValues(parsed.value.value);
      case ArtifactKind.yaml:
        if (parsed is YamlOk) return _structuredValues(parsed.value);
      case ArtifactKind.toml:
        if (parsed is TomlOk) return _structuredValues(parsed.value);
      case ArtifactKind.uuid:
      case ArtifactKind.ip:
      case ArtifactKind.number:
      case ArtifactKind.timestamp:
      case ArtifactKind.cron:
      case ArtifactKind.color:
      case ArtifactKind.math:
      case ArtifactKind.bps:
      case ArtifactKind.bytes:
      case ArtifactKind.list:
      case ArtifactKind.hash:
      case ArtifactKind.unknown:
        break;
    }
    return const <_DerivedValue>[];
  }

  List<_DerivedValue> _urlValues(String raw) {
    final List<_DerivedValue> values = <_DerivedValue>[];
    final String trimmed = raw.trim();
    try {
      final String decoded = Uri.decodeComponent(trimmed);
      if (decoded != trimmed) {
        values.add(
          _DerivedValue(
            label: 'Percent-decoded text',
            protectedLabel: 'Percent-decoded text',
            evidence: 'Decoded percent-encoded URL bytes.',
            typeKey: 'string',
            text: decoded,
          ),
        );
      }
    } on FormatException {
      // The detector can accept a valid query around a malformed component.
    }
    try {
      final Uri? uri = Uri.tryParse(trimmed);
      if (uri == null) return values;
      final Map<String, List<String>> query = uri.queryParametersAll;
      final List<String> keys = query.keys.toList()..sort();
      int ordinal = 0;
      for (final String key in keys) {
        for (final String value in query[key]!) {
          ordinal++;
          values.add(
            _DerivedValue(
              label: 'Query "$key"',
              protectedLabel: 'Query value $ordinal',
              evidence: 'Extracted a decoded URL query value.',
              typeKey: 'string',
              text: value,
            ),
          );
          if (values.length > ArtifactInspector.maxChildren) {
            _truncated = true;
            return values.take(ArtifactInspector.maxChildren).toList();
          }
        }
      }
      if (uri.fragment.isNotEmpty) {
        if (values.length >= ArtifactInspector.maxChildren) {
          _truncated = true;
        } else {
          values.add(
            _DerivedValue(
              label: 'URL fragment',
              protectedLabel: 'URL fragment',
              evidence: 'Extracted a decoded URL fragment.',
              typeKey: 'string',
              text: uri.fragment,
            ),
          );
        }
      }
    } on FormatException {
      // Malformed query escapes fail closed after any safe whole-value decode.
    }
    return values;
  }

  List<_DerivedValue> _structuredValues(Object? value) {
    final List<_DerivedValue> values = <_DerivedValue>[];
    if (value is Map) {
      if (value.length > ArtifactInspector.maxChildren) _truncated = true;
      int index = 0;
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        if (values.length >= ArtifactInspector.maxChildren) break;
        final String? text = _structuredText(entry.value);
        if (text == null) continue;
        index++;
        values.add(
          _DerivedValue(
            label: 'Field "${entry.key}"',
            protectedLabel: 'Field $index',
            evidence: 'Extracted one structured value.',
            typeKey: entry.value.runtimeType.toString(),
            text: text,
          ),
        );
      }
    } else if (value is List) {
      if (value.length > ArtifactInspector.maxChildren) _truncated = true;
      for (
        int i = 0;
        i < value.length && values.length < ArtifactInspector.maxChildren;
        i++
      ) {
        final String? text = _structuredText(value[i]);
        if (text == null) continue;
        values.add(
          _DerivedValue(
            label: 'Item ${i + 1}',
            protectedLabel: 'Item ${i + 1}',
            evidence: 'Extracted one structured value.',
            typeKey: value[i].runtimeType.toString(),
            text: text,
          ),
        );
      }
    }
    return values;
  }

  String? _structuredText(Object? value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is Map || value is List) {
      if (!_jsonShapeWithinBounds(value)) {
        _truncated = true;
        return null;
      }
      try {
        return jsonEncode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _reserveNode() {
    if (_nodes >= ArtifactInspector.maxNodes) {
      _truncated = true;
      return false;
    }
    _nodes++;
    return true;
  }

  bool _withinLimit(String value) {
    if (value.length > ArtifactInspector.maxTextBytes) return false;
    try {
      return utf8.encode(value).length <= ArtifactInspector.maxTextBytes;
    } catch (_) {
      return false;
    }
  }

  List<DetectionMatch<Object?>> _safeDetect(String value) {
    if (!_nestingWithinLimit(value)) {
      _truncated = true;
      return const <DetectionMatch<Object?>>[];
    }
    try {
      return UtilityCatalog.detectArtifacts(value, provenance: provenance);
    } catch (_) {
      return const <DetectionMatch<Object?>>[];
    }
  }

  bool _nestingWithinLimit(String value) {
    final String trimmed = value.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return true;
    bool quoted = false;
    bool escaped = false;
    int depth = 0;
    for (final int unit in trimmed.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5c) {
          escaped = true;
        } else if (unit == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (unit == 0x22) {
        quoted = true;
      } else if (unit == 0x7b || unit == 0x5b) {
        if (++depth > ArtifactInspector.maxDepth) return false;
      } else if (unit == 0x7d || unit == 0x5d) {
        depth--;
      }
    }
    return true;
  }

  bool _jsonShapeWithinBounds(Object? value, [int depth = 0]) {
    if (depth > ArtifactInspector.maxDepth) return false;
    if (value is Map) {
      if (value.length > ArtifactInspector.maxChildren) return false;
      return value.entries.every(
        (MapEntry<dynamic, dynamic> entry) =>
            entry.key is String &&
            _jsonShapeWithinBounds(entry.value, depth + 1),
      );
    }
    if (value is List) {
      if (value.length > ArtifactInspector.maxChildren) return false;
      return value.every(
        (Object? child) => _jsonShapeWithinBounds(child, depth + 1),
      );
    }
    return value == null || value is String || value is num || value is bool;
  }

  String _digest(String typeKey, String value) {
    final String normalized = value.trim();
    return sha256.convert(utf8.encode('$typeKey\u0000$normalized')).toString();
  }

  Artifact<Object?> _withSensitivity(
    Artifact<Object?> artifact,
    bool sensitive,
  ) => Artifact<Object?>(
    kind: artifact.kind,
    rawValue: artifact.rawValue,
    provenance: artifact.provenance,
    parserResult: artifact.parserResult,
    sensitivity: sensitive
        ? ArtifactSensitivity.sensitive
        : ArtifactSensitivity.standard,
  );

  String _kindLabel(ArtifactKind kind) => switch (kind) {
    ArtifactKind.uuid => 'UUID',
    ArtifactKind.ip => 'IP / CIDR',
    ArtifactKind.number => 'Number',
    ArtifactKind.timestamp => 'Timestamp',
    ArtifactKind.cron => 'Cron',
    ArtifactKind.json => 'JSON',
    ArtifactKind.yaml => 'YAML',
    ArtifactKind.toml => 'TOML',
    ArtifactKind.jwt => 'JWT',
    ArtifactKind.base64 => 'Base64',
    ArtifactKind.url => 'URL',
    ArtifactKind.color => 'Color',
    ArtifactKind.math => 'Math',
    ArtifactKind.bps => 'Basis points',
    ArtifactKind.bytes => 'Bytes',
    ArtifactKind.list => 'List',
    ArtifactKind.hash => 'Hash',
    ArtifactKind.unknown => 'Unknown',
  };
}

class _DerivedValue {
  const _DerivedValue({
    required this.label,
    required this.protectedLabel,
    required this.evidence,
    required this.typeKey,
    required this.text,
  });

  factory _DerivedValue.json(String label, String text) => _DerivedValue(
    label: label,
    protectedLabel: label,
    evidence: 'Decoded a structured JSON layer.',
    typeKey: 'json',
    text: text,
  );

  final String label;
  final String protectedLabel;
  final String evidence;
  final String typeKey;
  final String text;
}
