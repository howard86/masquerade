import 'package:flutter/cupertino.dart';

import '../../models/artifact.dart';
import '../../models/work_session.dart';
import '../../state/work_session_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/mq/tool_action_bar.dart';
import '../../widgets/mq/mq_surface.dart';
import '../../widgets/tool_bodies/open_in_footer.dart';
import '../../widgets/tool_bodies/seed_source.dart';

/// Shared route wrapper for every catalog tool. Pushes a Cupertino scaffold
/// with a back-enabled navigation bar and renders the descriptor's body
/// widget seeded with [seed]. Cross-tool "Open in X" footers stack new
/// `ToolDetailRoute`s on top so the navigation history retraces the data
/// pipeline.
///
/// Renders a pinned [ToolActionBar] at the safe-area bottom. Bodies bind
/// their paste/clear handlers on the [ToolActionBarController]; the bar
/// floats above the keyboard via `MediaQuery.viewInsets.bottom`.
class ToolDetailRoute extends StatefulWidget {
  const ToolDetailRoute({
    super.key,
    required this.descriptor,
    this.seed,
    this.initialArtifact,
    this.sessionStepIndex,
  });

  final UtilityDescriptor descriptor;
  final String? seed;
  final Artifact<Object?>? initialArtifact;
  final int? sessionStepIndex;

  static Future<void> push(
    BuildContext context,
    UtilityDescriptor descriptor, {
    String? seed,
    Artifact<Object?>? initialArtifact,
    int? sessionStepIndex,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ToolDetailRoute(
          descriptor: descriptor,
          seed: seed,
          initialArtifact: initialArtifact,
          sessionStepIndex: sessionStepIndex,
        ),
      ),
    );
  }

  @override
  State<ToolDetailRoute> createState() => _ToolDetailRouteState();
}

class _ToolDetailRouteState extends State<ToolDetailRoute> {
  final ToolActionBarController _actionBar = ToolActionBarController();
  WorkSession? _settingsLease;

  @override
  void dispose() {
    _actionBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String? s = widget.seed;
    final SeedSource src = (s != null && s.isNotEmpty)
        ? SeedSource.paste
        : SeedSource.none;
    final WorkSessionController? sessions = WorkSessionScope.maybeOf(context);
    final int? stepIndex = widget.sessionStepIndex;
    final steps = sessions?.session?.steps;
    final bool currentSessionStep =
        sessions != null && stepIndex != null && sessions.isCurrent(stepIndex);
    final bool protectedSession =
        sessions != null &&
        steps != null &&
        stepIndex != null &&
        stepIndex >= 0 &&
        stepIndex < steps.length &&
        steps[stepIndex].input.isSensitive;
    final WorkflowStep? sessionStep =
        steps != null &&
            stepIndex != null &&
            stepIndex >= 0 &&
            stepIndex < steps.length
        ? steps[stepIndex]
        : null;
    final String? expectedNextToolId = currentSessionStep
        ? sessions.expectedNextToolId(stepIndex)
        : null;
    if (currentSessionStep && _settingsLease == null) {
      _settingsLease = sessions.session;
    }
    final OpenInToolCallback? switchTool = stepIndex == null
        ? (UtilityDescriptor target, String input) => ToolDetailRoute.push(
            context,
            target,
            seed: input.isNotEmpty ? input : null,
          )
        : currentSessionStep
        ? (UtilityDescriptor target, String input) {
            final int? next = sessions.addNext(stepIndex, target, input);
            if (next == null) return;
            final nextSteps = sessions.session?.steps;
            if (next < 0 || nextSteps == null || next >= nextSteps.length) {
              return;
            }
            ToolDetailRoute.push(
              context,
              target,
              seed: input,
              initialArtifact: nextSteps[next].input,
              sessionStepIndex: next,
            );
          }
        : null;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        middle: Text(
          widget.descriptor.name,
          style: MqTextStyles.headline.copyWith(color: c.textPri),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.lg,
                  MqSpacing.md,
                  MqSpacing.lg,
                  MqSpacing.md,
                ),
                child: MobileSessionRouteScope(
                  addNext: currentSessionStep,
                  protectedSession: protectedSession,
                  expectedNextToolId: expectedNextToolId,
                  settings: sessionStep?.settings ?? const <String, Object?>{},
                  onSettingsChanged:
                      currentSessionStep &&
                          sessionStep != null &&
                          _settingsLease != null
                      ? (Map<String, Object?> settings) {
                          if (sessions.updateSettings(
                            stepIndex,
                            _settingsLease!,
                            settings,
                          )) {
                            _settingsLease = sessions.session;
                          }
                        }
                      : null,
                  child: widget.descriptor.builder(
                    context,
                    initialInput: s,
                    initialArtifact: widget.initialArtifact,
                    seedSource: src,
                    onSwitchTool: switchTool,
                    actionBar: _actionBar,
                  ),
                ),
              ),
            ),
            if (sessions != null && stepIndex != null)
              ListenableBuilder(
                listenable: sessions,
                builder: (BuildContext context, _) {
                  final String? error = sessions.workflowError;
                  if (error == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MqSpacing.lg,
                      0,
                      MqSpacing.lg,
                      MqSpacing.sm,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      label: error,
                      child: MqSurface(
                        background: c.warningBg,
                        borderColor: c.warning,
                        child: Text(
                          error,
                          style: MqTextStyles.subhead.copyWith(
                            color: c.textPri,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ToolActionBar(controller: _actionBar),
          ],
        ),
      ),
    );
  }
}
