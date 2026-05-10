import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/tool_bodies/seed_source.dart';

/// Shared route wrapper for every catalog tool. Pushes a Cupertino scaffold
/// with a back-enabled navigation bar and renders the descriptor's body
/// widget seeded with [seed]. Cross-tool "Open in X" footers stack new
/// `ToolDetailRoute`s on top so the navigation history retraces the data
/// pipeline.
class ToolDetailRoute extends StatelessWidget {
  const ToolDetailRoute({super.key, required this.descriptor, this.seed});

  final UtilityDescriptor descriptor;
  final String? seed;

  static Future<void> push(
    BuildContext context,
    UtilityDescriptor descriptor, {
    String? seed,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ToolDetailRoute(descriptor: descriptor, seed: seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String? s = seed;
    final SeedSource src = (s != null && s.isNotEmpty)
        ? SeedSource.paste
        : SeedSource.none;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        previousPageTitle: 'Home',
        middle: Text(
          descriptor.name,
          style: MqTextStyles.headline.copyWith(color: c.textPri),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg,
            MqSpacing.md,
            MqSpacing.lg,
            MqLayout.tabBarClearance,
          ),
          child: descriptor.builder(
            context,
            initialInput: s,
            seedSource: src,
            onSwitchTool: (UtilityDescriptor target, String input) =>
                push(context, target, seed: input.isNotEmpty ? input : null),
          ),
        ),
      ),
    );
  }
}
