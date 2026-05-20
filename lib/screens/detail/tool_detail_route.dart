import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/mq/tool_action_bar.dart';
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
  State<ToolDetailRoute> createState() => _ToolDetailRouteState();
}

class _ToolDetailRouteState extends State<ToolDetailRoute> {
  final ToolActionBarController _actionBar = ToolActionBarController();

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

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        previousPageTitle: 'Home',
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
                child: widget.descriptor.builder(
                  context,
                  initialInput: s,
                  seedSource: src,
                  onSwitchTool: (UtilityDescriptor target, String input) =>
                      ToolDetailRoute.push(
                        context,
                        target,
                        seed: input.isNotEmpty ? input : null,
                      ),
                  actionBar: _actionBar,
                ),
              ),
            ),
            ToolActionBar(controller: _actionBar),
          ],
        ),
      ),
    );
  }
}
