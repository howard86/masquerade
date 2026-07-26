import 'work_session.dart';

typedef SavedToolPolicy = bool Function(String toolId);

/// A reusable tool sequence. Captured artifacts are deliberately not modeled.
class SavedWorkflow {
  SavedWorkflow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required List<SavedWorkflowStep> steps,
  }) : steps = List<SavedWorkflowStep>.unmodifiable(steps) {
    if (!_identifier.hasMatch(id) ||
        name.trim().isEmpty ||
        isProtectedWorkflowString(name) ||
        steps.isEmpty ||
        updatedAt.isBefore(createdAt)) {
      throw ArgumentError('Saved workflow fields cannot be empty.');
    }
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SavedWorkflowStep> steps;

  bool get available => steps.every((SavedWorkflowStep step) => step.available);

  SavedWorkflow rename(String value) => SavedWorkflow(
    id: id,
    name: value.trim(),
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    steps: steps,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'steps': steps.map((SavedWorkflowStep step) => step.toJson()).toList(),
  };

  static SavedWorkflow? tryFromJson(
    Object? value, {
    required SavedToolPolicy isKnownTool,
  }) {
    try {
      if (value is! Map<String, dynamic> ||
          value['id'] is! String ||
          value['name'] is! String ||
          value['createdAt'] is! int ||
          value['updatedAt'] is! int ||
          value['steps'] is! List<dynamic>) {
        return null;
      }
      final List<SavedWorkflowStep> steps = <SavedWorkflowStep>[];
      for (final Object? raw in value['steps'] as List<dynamic>) {
        final SavedWorkflowStep? step = SavedWorkflowStep.tryFromJson(
          raw,
          isKnownTool: isKnownTool,
        );
        if (step == null) return null;
        steps.add(step);
      }
      return SavedWorkflow(
        id: value['id'] as String,
        name: value['name'] as String,
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

class SavedWorkflowStep {
  SavedWorkflowStep({
    required this.toolId,
    required Map<String, Object?> settings,
    this.available = true,
  }) : settings = sanitizeWorkflowSettings(settings) {
    if (!_identifier.hasMatch(toolId)) {
      throw ArgumentError.value(toolId, 'toolId');
    }
  }

  final String toolId;
  final Map<String, Object?> settings;
  final bool available;

  Map<String, Object?> toJson() => <String, Object?>{
    'toolId': toolId,
    'settings': settings,
  };

  static SavedWorkflowStep? tryFromJson(
    Object? value, {
    required SavedToolPolicy isKnownTool,
  }) {
    try {
      if (value is! Map<String, dynamic> ||
          value['toolId'] is! String ||
          value['settings'] is! Map<String, dynamic>) {
        return null;
      }
      final String toolId = value['toolId'] as String;
      return SavedWorkflowStep(
        toolId: toolId,
        settings: Map<String, Object?>.from(
          value['settings'] as Map<String, dynamic>,
        ),
        available: isKnownTool(toolId),
      );
    } catch (_) {
      return null;
    }
  }
}

final RegExp _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');
