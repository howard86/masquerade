import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

class MqSearchBar extends StatelessWidget {
  const MqSearchBar({
    super.key,
    required this.controller,
    this.placeholder = 'Search utilities',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.showShortcutHint = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MqRadius.sm),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Icon(MqIcons.search, size: 16, color: c.textTer),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              autofocus: autofocus,
              placeholder: placeholder,
              placeholderStyle: MqTextStyles.body.copyWith(color: c.textTer),
              style: MqTextStyles.body.copyWith(color: c.textPri),
              cursorColor: c.accent,
              decoration: const BoxDecoration(),
              padding: EdgeInsets.zero,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showShortcutHint)
            Text(
              '⌘K',
              style: MqTextStyles.footnote.copyWith(
                color: c.textTer,
                fontFamily: MqTextStyles.monoFamily,
                fontFamilyFallback: MqTextStyles.monoFallback,
              ),
            ),
        ],
      ),
    );
  }
}
