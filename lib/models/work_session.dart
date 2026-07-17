import 'dart:convert';

import '../utils/sensitive_data_policy.dart';
import 'artifact.dart';

typedef ToolPolicy = bool Function(String toolId);

enum WorkflowStepStatus { pending, running, completed, failed }

/// One tool invocation in a linear work session.
class WorkflowStep {
  WorkflowStep({
    required this.toolId,
    required this.input,
    required Map<String, Object?> settings,
    required this.status,
    this.output,
    this.toolAvailable = true,
  }) : settings = _freezeSettings(settings) {
    _validateIdentifier(toolId, 'toolId');
  }

  final String toolId;
  final Artifact<Object?> input;
  final Map<String, Object?> settings;
  final Artifact<Object?>? output;
  final WorkflowStepStatus status;

  /// False when restoration knows that [toolId] is no longer installed.
  final bool toolAvailable;
}

/// A shell-independent, ordered sequence of artifact transformations.
class WorkSession {
  WorkSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required List<WorkflowStep> steps,
  }) : steps = List<WorkflowStep>.unmodifiable(steps) {
    _validateIdentifier(id, 'id');
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(updatedAt, 'updatedAt', 'precedes createdAt');
    }
  }

  static const int schemaVersion = 1;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkflowStep> steps;

  /// [canPersistTool] is required so the shared model never guesses a shell's
  /// catalog history policy. Protected steps retain only artifact metadata.
  Map<String, Object?> toJson({required ToolPolicy canPersistTool}) =>
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': isProtectedWorkflowString(name) ? 'Untitled session' : name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'steps': steps
            .map(
              (WorkflowStep step) =>
                  _stepToJson(step, canPersistTool: canPersistTool),
            )
            .toList(),
      };

  /// Returns null for malformed, older, or newer persisted schemas.
  static WorkSession? tryFromJson(Object? value, {ToolPolicy? isKnownTool}) {
    try {
      if (value is! Map<String, dynamic> ||
          value['schemaVersion'] != schemaVersion ||
          value['id'] is! String ||
          value['name'] is! String ||
          value['createdAt'] is! int ||
          value['updatedAt'] is! int ||
          value['steps'] is! List<dynamic>) {
        return null;
      }

      final List<WorkflowStep> steps = <WorkflowStep>[];
      for (final Object? raw in value['steps'] as List<dynamic>) {
        final WorkflowStep? step = _stepFromJson(raw, isKnownTool: isKnownTool);
        if (step == null) return null;
        steps.add(step);
      }

      return WorkSession(
        id: value['id'] as String,
        name: isProtectedWorkflowString(value['name'] as String)
            ? 'Untitled session'
            : value['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          value['createdAt'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          value['updatedAt'] as int,
        ),
        steps: steps,
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, Object?> _stepToJson(
  WorkflowStep step, {
  required ToolPolicy canPersistTool,
}) {
  final bool protectArtifacts =
      !canPersistTool(step.toolId) ||
      step.input.isSensitive ||
      isProtectedWorkflowString(step.input.rawValue) ||
      (step.output != null &&
          isProtectedWorkflowString(step.output!.rawValue)) ||
      (step.output?.isSensitive ?? false);
  return <String, Object?>{
    'toolId': step.toolId,
    'input': _artifactToJson(step.input, redact: protectArtifacts),
    'settings': protectArtifacts
        ? const <String, Object?>{}
        : sanitizeWorkflowSettings(step.settings),
    if (step.output case final Artifact<Object?> output)
      'output': _artifactToJson(output, redact: protectArtifacts),
    'status': step.status.name,
  };
}

WorkflowStep? _stepFromJson(Object? value, {required ToolPolicy? isKnownTool}) {
  if (value is! Map<String, dynamic> ||
      value['toolId'] is! String ||
      value['input'] is! Map<String, dynamic> ||
      value['settings'] is! Map<String, dynamic> ||
      value['status'] is! String) {
    return null;
  }
  final String toolId = value['toolId'] as String;
  if (!_validIdentifier(toolId)) return null;
  final bool toolAvailable = isKnownTool?.call(toolId) ?? false;
  final Artifact<Object?>? input = _artifactFromJson(
    value['input'],
    forceRedact: !toolAvailable,
  );
  final Artifact<Object?>? output = value['output'] == null
      ? null
      : _artifactFromJson(value['output'], forceRedact: !toolAvailable);
  final WorkflowStepStatus? status = _enumByName(
    WorkflowStepStatus.values,
    value['status'] as String,
  );
  if (input == null ||
      (value['output'] != null && output == null) ||
      status == null ||
      !_isJsonValue(value['settings'])) {
    return null;
  }
  return WorkflowStep(
    toolId: toolId,
    input: input,
    settings: toolAvailable
        ? sanitizeWorkflowSettings(
            Map<String, Object?>.from(
              value['settings'] as Map<String, dynamic>,
            ),
          )
        : const <String, Object?>{},
    output: output,
    status: status,
    toolAvailable: toolAvailable,
  );
}

Map<String, Object?> _artifactToJson(
  Artifact<Object?> artifact, {
  required bool redact,
}) => <String, Object?>{
  'kind': artifact.kind.name,
  'provenance': artifact.provenance.name,
  if (redact) 'redacted': true else 'rawValue': artifact.rawValue,
};

Artifact<Object?>? _artifactFromJson(
  Object? value, {
  bool forceRedact = false,
}) {
  if (value is! Map<String, dynamic> ||
      value['kind'] is! String ||
      value['provenance'] is! String) {
    return null;
  }
  final ArtifactKind? kind = _enumByName(
    ArtifactKind.values,
    value['kind'] as String,
  );
  final ArtifactProvenance? provenance = _enumByName(
    ArtifactProvenance.values,
    value['provenance'] as String,
  );
  final bool redacted = forceRedact || value['redacted'] == true;
  if (kind == null ||
      provenance == null ||
      (!redacted && value['rawValue'] is! String)) {
    return null;
  }
  final Artifact<Object?> restored = Artifact<Object?>(
    kind: kind,
    rawValue: redacted ? SensitiveDataPolicy.mask : value['rawValue'] as String,
    provenance: provenance,
    sensitivity: redacted
        ? ArtifactSensitivity.sensitive
        : ArtifactSensitivity.standard,
  );
  if (!restored.isSensitive && !isProtectedWorkflowString(restored.rawValue)) {
    return restored;
  }
  return Artifact<Object?>(
    kind: kind,
    rawValue: SensitiveDataPolicy.mask,
    provenance: provenance,
    sensitivity: ArtifactSensitivity.sensitive,
  );
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return null;
}

final Object _omitted = Object();

/// Returns a deeply frozen settings snapshot with payload-like values removed.
Map<String, Object?> sanitizeWorkflowSettings(Map<String, Object?> settings) {
  final Map<String, Object?> safe = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in settings.entries) {
    if (_protectedSettingKey(entry.key, entry.value)) continue;
    final Object? value = _sanitizeSettingValue(entry.value);
    if (!identical(value, _omitted)) safe[entry.key] = value;
  }
  return _freezeSettings(safe);
}

Object? _sanitizeSettingValue(Object? value) {
  if (value == null || value is num || value is bool) return value;
  if (value is String) {
    return isProtectedWorkflowString(value) ? _omitted : value;
  }
  if (value is List<Object?>) {
    if (value.isNotEmpty &&
        value.every((Object? item) => item is num) &&
        isProtectedWorkflowString(jsonEncode(value))) {
      return _omitted;
    }
    return <Object?>[
      for (final Object? item in value)
        if (_sanitizeSettingValue(item) case final Object? safe
            when !identical(safe, _omitted))
          safe,
    ];
  }
  if (value is Map<String, Object?>) {
    return sanitizeWorkflowSettings(value);
  }
  return _omitted;
}

bool _protectedSettingKey(String key, Object? value) {
  if (isProtectedWorkflowString(key)) return true;
  final String normalized = key.trim().replaceAll(RegExp(r'[-_. ]'), '');
  if (RegExp(
    r'^(?:generated(?:payload|value|token|password)?|output|payload|result)$',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return true;
  }
  final String scalar = value is String || value is num || value is bool
      ? '$value'
      : '';
  return SensitiveDataPolicy.containsSensitiveArtifact('{$key=$scalar}');
}

bool _isJsonValue(Object? value) {
  if (value == null || value is String || value is bool) return true;
  if (value is num) return value.isFinite;
  if (value is List<Object?>) return value.every(_isJsonValue);
  if (value is Map<Object?, Object?>) {
    return value.entries.every(
      (MapEntry<Object?, Object?> entry) =>
          entry.key is String && _isJsonValue(entry.value),
    );
  }
  return false;
}

Map<String, Object?> _freezeSettings(Map<String, Object?> settings) {
  if (!_isJsonValue(settings)) {
    throw ArgumentError.value(settings, 'settings', 'must be JSON-safe');
  }
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    for (final MapEntry<String, Object?> entry in settings.entries)
      entry.key: _freezeJsonValue(entry.value),
  });
}

Object? _freezeJsonValue(Object? value) {
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeJsonValue));
  }
  if (value is Map<String, Object?>) return _freezeSettings(value);
  return value;
}

final RegExp _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');

bool _validIdentifier(String value) => _identifier.hasMatch(value);

void _validateIdentifier(String value, String name) {
  if (!_validIdentifier(value)) throw ArgumentError.value(value, name);
}

bool isProtectedWorkflowString(String value) =>
    <String?>[null, 'base64', 'bytes', 'url'].any(
      (String? utilityId) => SensitiveDataPolicy.protects(
        utilityId: utilityId,
        values: <String>[value],
      ),
    );
