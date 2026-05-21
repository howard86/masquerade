import 'package:flutter/cupertino.dart';

import '../../state/view_mode_controller.dart';
import '../../theme/mq_theme.dart';
import 'mq_button.dart';
import 'mq_icons.dart';

/// Glass button that switches the app to [target] layout. Used in three places:
/// the desktop sidebar (target: mobile, full-width labelled), and — in [compact]
/// form — an icon-only chip tucked into the iPhone frame's status strip on wide
/// web (target: desktop).
class ViewModeToggleButton extends StatelessWidget {
  const ViewModeToggleButton({
    super.key,
    required this.target,
    required this.label,
    this.full = false,
    this.compact = false,
  }) : assert(!(compact && full), 'compact chips have no full-width variant');

  final MqViewMode target;
  final String label;
  final bool full;

  /// Render an icon-only circular chip instead of a labelled pill. Used inside
  /// the iPhone frame where there's no room for text beside the Dynamic Island.
  final bool compact;

  /// Diameter of the [compact] chip (logical px).
  static const double compactSize = 32;

  /// Stable handle for the compact chip (it has no visible text to find by).
  static const Key compactKey = ValueKey<String>('view_mode_toggle_compact');

  IconData get _icon =>
      target == MqViewMode.desktop ? MqIcons.monitor : MqIcons.smartphone;

  @override
  Widget build(BuildContext context) {
    void onPressed() => ViewModeScope.of(context).setMode(target);

    if (compact) {
      final c = context.mq.colors;
      return Semantics(
        button: true,
        label: label,
        child: CupertinoButton(
          key: compactKey,
          padding: EdgeInsets.zero,
          minimumSize: const Size(compactSize, compactSize),
          borderRadius: BorderRadius.circular(compactSize / 2),
          pressedOpacity: 0.85,
          onPressed: onPressed,
          child: Container(
            width: compactSize,
            height: compactSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.borderStrong, width: 0.5),
            ),
            child: Icon(_icon, size: 16, color: c.textPri),
          ),
        ),
      );
    }

    return MqButton(
      label: label,
      icon: _icon,
      variant: MqButtonVariant.glass,
      size: MqButtonSize.sm,
      full: full,
      onPressed: onPressed,
    );
  }
}
