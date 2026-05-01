import 'package:flutter/cupertino.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Cupertino sliding segmented control themed with Masquerade tokens.
class MqSegmented<T extends Object> extends StatelessWidget {
  const MqSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.full = true,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    final Widget control = CupertinoSlidingSegmentedControl<T>(
      groupValue: selected,
      onValueChanged: (T? v) {
        if (v != null) onChanged(v);
      },
      thumbColor: c.surface,
      backgroundColor: c.surface2,
      children: <T, Widget>{
        for (final MapEntry<T, String> entry in options.entries)
          entry.key: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Text(
              entry.value,
              style: MqTextStyles.subhead.copyWith(
                color: entry.key == selected ? c.textPri : c.textSec,
                fontWeight: entry.key == selected
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
      },
    );

    return full ? SizedBox(width: double.infinity, child: control) : control;
  }
}
