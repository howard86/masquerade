import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/tool_action_bar.dart';
import '../../widgets/tool_bodies/seed_source.dart';

/// In-pane tool host for the desktop shell. Mirrors `ToolDetailRoute` but lives
/// inside the content pane (no route push): a back header, the scrollable tool
/// body, and a pinned [ToolActionBar]. The sidebar stays put around it.
class DesktopToolView extends StatefulWidget {
  const DesktopToolView({
    super.key,
    required this.descriptor,
    required this.seed,
    required this.onBack,
    required this.onSwitchTool,
  });

  final UtilityDescriptor descriptor;
  final String? seed;
  final VoidCallback onBack;
  final OpenInToolCallback onSwitchTool;

  @override
  State<DesktopToolView> createState() => _DesktopToolViewState();
}

class _DesktopToolViewState extends State<DesktopToolView> {
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

    return ColoredBox(
      color: c.bg,
      child: Column(
        children: <Widget>[
          _Header(title: widget.descriptor.name, onBack: widget.onBack),
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
                onSwitchTool: widget.onSwitchTool,
                actionBar: _actionBar,
              ),
            ),
          ),
          ToolActionBar(controller: _actionBar),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
              minimumSize: const Size(0, 36),
              onPressed: onBack,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(MqIcons.chevL, size: 18, color: c.accent),
                  const SizedBox(width: 2),
                  Text(
                    'Back',
                    style: MqTextStyles.body.copyWith(color: c.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: MqTextStyles.headline.copyWith(color: c.textPri),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
