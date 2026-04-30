import 'package:flutter/cupertino.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import 'mb_icons.dart';

class MBSearchBar extends StatelessWidget {
  const MBSearchBar({
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
    final c = context.mb.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: MBSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MBRadius.sm),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Icon(MBIcons.search, size: 16, color: c.textTer),
          const SizedBox(width: MBSpacing.sm),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              autofocus: autofocus,
              placeholder: placeholder,
              placeholderStyle: MBTextStyles.body.copyWith(color: c.textTer),
              style: MBTextStyles.body.copyWith(color: c.textPri),
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
              style: MBTextStyles.footnote.copyWith(
                color: c.textTer,
                fontFamily: MBTextStyles.monoFamily,
                fontFamilyFallback: MBTextStyles.monoFallback,
              ),
            ),
        ],
      ),
    );
  }
}
