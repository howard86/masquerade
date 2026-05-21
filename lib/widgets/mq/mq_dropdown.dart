import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

/// Editorial dropdown — labeled tap target that opens a `CupertinoActionSheet`
/// of [options]. Use when the option count outgrows what `MqSegmented`
/// renders cleanly (≥4 options). Disabled state greys the chevron and
/// suppresses the picker so the body can gate it on context.
class MqDropdown<T extends Object> extends StatelessWidget {
  const MqDropdown({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.full = true,
  });

  final String label;
  final T selected;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final TextStyle labelStyle = MqTextStyles.sectionLabel.copyWith(
      color: c.textSec,
    );
    final TextStyle valueStyle = MqTextStyles.headline.copyWith(
      color: enabled ? c.textPri : c.textTer,
    );
    final String? selectedLabel = options[selected];
    final Color borderColor = enabled ? c.borderStrong : c.border;
    final Color chevronColor = enabled ? c.textSec : c.textTer;

    final Widget control = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MqRadius.sm),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: 10,
        ),
        borderRadius: BorderRadius.circular(MqRadius.sm),
        onPressed: enabled ? () => _open(context) : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label.toUpperCase(), style: labelStyle),
                  const SizedBox(height: 2),
                  Text(
                    selectedLabel ?? '',
                    style: valueStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(MqIcons.chevD, size: 16, color: chevronColor),
          ],
        ),
      ),
    );

    final Widget sized = full
        ? SizedBox(width: double.infinity, child: control)
        : control;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, ${selectedLabel ?? ''}',
      child: sized,
    );
  }

  Future<void> _open(BuildContext context) async {
    final T? choice = await showCupertinoModalPopup<T>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(label),
        actions: <Widget>[
          for (final MapEntry<T, String> entry in options.entries)
            CupertinoActionSheetAction(
              isDefaultAction: entry.key == selected,
              onPressed: () => Navigator.of(ctx).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice != null && choice != selected) onChanged(choice);
  }
}
