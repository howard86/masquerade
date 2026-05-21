import 'package:flutter/cupertino.dart';

import '../../state/view_mode_controller.dart';
import 'mq_button.dart';
import 'mq_icons.dart';

/// Glass button that switches the app to [target] layout. Used in two places:
/// the desktop sidebar (target: mobile) and floating beside the iPhone frame
/// on wide web (target: desktop).
class ViewModeToggleButton extends StatelessWidget {
  const ViewModeToggleButton({
    super.key,
    required this.target,
    required this.label,
    this.full = false,
  });

  final MqViewMode target;
  final String label;
  final bool full;

  @override
  Widget build(BuildContext context) {
    return MqButton(
      label: label,
      icon: target == MqViewMode.desktop ? MqIcons.monitor : MqIcons.smartphone,
      variant: MqButtonVariant.glass,
      size: MqButtonSize.sm,
      full: full,
      onPressed: () => ViewModeScope.of(context).setMode(target),
    );
  }
}
