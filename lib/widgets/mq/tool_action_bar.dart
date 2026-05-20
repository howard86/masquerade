import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import 'mq_button.dart';
import 'mq_icons.dart';

/// Holds the paste/clear handlers and optional center action that a
/// [ToolDetailRoute] should render in its pinned bottom action bar.
///
/// Each tool body binds its handlers on `initState` so the route can drive
/// the bar from outside the body's scroll view. Bodies that don't need a
/// bar simply skip the bind call.
class ToolActionBarController extends ChangeNotifier {
  VoidCallback? _onPaste;
  VoidCallback? _onClear;
  Widget? _center;

  VoidCallback? get onPaste => _onPaste;
  VoidCallback? get onClear => _onClear;
  Widget? get center => _center;

  bool get hasBinding => _onPaste != null || _onClear != null;

  void bind({VoidCallback? onPaste, VoidCallback? onClear, Widget? center}) {
    _onPaste = onPaste;
    _onClear = onClear;
    _center = center;
    notifyListeners();
  }
}

/// Bottom action bar anchored above the keyboard. Renders Paste leading,
/// Clear trailing, with an optional center slot for tool-specific actions.
class ToolActionBar extends StatelessWidget {
  const ToolActionBar({super.key, required this.controller});

  final ToolActionBarController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final MediaQueryData media = MediaQuery.of(context);
    final double bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        if (!controller.hasBinding) return const SizedBox.shrink();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.borderStrong, width: 0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MqSpacing.lg,
              MqSpacing.sm,
              MqSpacing.lg,
              MqSpacing.sm + bottomInset,
            ),
            child: Row(
              children: <Widget>[
                // Tools that take no single input (e.g. Diff's two fields) bind
                // no paste handler; hide the leading Paste rather than show a
                // dead button.
                if (controller.onPaste != null) ...<Widget>[
                  Expanded(
                    child: MqButton(
                      label: 'Paste',
                      icon: MqIcons.paste,
                      variant: MqButtonVariant.glass,
                      onPressed: controller.onPaste!,
                      full: true,
                    ),
                  ),
                  const SizedBox(width: MqSpacing.sm),
                ],
                if (controller.center != null) ...<Widget>[
                  Expanded(child: controller.center!),
                  const SizedBox(width: MqSpacing.sm),
                ],
                Expanded(
                  child: MqButton(
                    label: 'Clear',
                    icon: MqIcons.clear,
                    variant: MqButtonVariant.glass,
                    onPressed: controller.onClear ?? () {},
                    full: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
