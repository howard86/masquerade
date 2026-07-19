import 'package:flutter/cupertino.dart';

import '../../models/artifact.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/tool_host.dart';

/// Shared route wrapper for every catalog tool. Pushes a Cupertino scaffold
/// with a back-enabled navigation bar and renders the descriptor's body
/// widget (via [ToolHost]) seeded with [seed]. Cross-tool "Open in X" footers
/// stack new `ToolDetailRoute`s on top so the navigation history retraces the
/// data pipeline.
///
/// The tool body, session wiring, and pinned `ToolActionBar` all live in
/// [ToolHost], which the tablet split-view detail pane reuses.
class ToolDetailRoute extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        middle: Text(
          descriptor.name,
          style: MqTextStyles.headline.copyWith(color: c.textPri),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: ToolHost(
        descriptor: descriptor,
        seed: seed,
        initialArtifact: initialArtifact,
        sessionStepIndex: sessionStepIndex,
      ),
    );
  }
}
