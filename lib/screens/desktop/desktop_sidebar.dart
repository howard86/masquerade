import 'package:flutter/cupertino.dart';

import '../../state/view_mode_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_wordmark.dart';
import '../../widgets/mq/view_mode_toggle_button.dart';

/// Left navigation rail for the web desktop shell: wordmark, the Home / History
/// / Settings rows, and a "Mobile view" toggle pinned to the bottom.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const List<({IconData icon, String label})> _items =
      <({IconData icon, String label})>[
        (icon: MqIcons.home, label: 'Home'),
        (icon: MqIcons.history, label: 'History'),
        (icon: MqIcons.setting, label: 'Settings'),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      width: MqLayout.sidebarWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: MqSpacing.sm),
                child: MqWordmark(size: 26),
              ),
              const SizedBox(height: MqSpacing.xl),
              for (int i = 0; i < _items.length; i++) ...<Widget>[
                _NavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
                const SizedBox(height: MqSpacing.xs),
              ],
              const Spacer(),
              const ViewModeToggleButton(
                target: MqViewMode.mobile,
                label: 'Mobile view',
                full: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color fg = selected ? c.accent : c.textSec;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? c.accentBg : null,
          borderRadius: BorderRadius.circular(MqRadius.sm),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: MqSpacing.md),
            Text(
              label,
              style: MqTextStyles.headline.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
