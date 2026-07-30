import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

/// Editorial search input — underline-only treatment matching MqInput.
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
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, _) {
              if (value.text.isNotEmpty) {
                return Semantics(
                  button: true,
                  label: 'Clear search',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    // Grow the tappable region toward the 44×44 iOS HIG
                    // minimum without enlarging the glyph or the bar itself.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: Center(
                        child: Icon(MqIcons.clear, size: 16, color: c.textTer),
                      ),
                    ),
                  ),
                );
              }
              if (showShortcutHint) {
                return Text(
                  '⌘K',
                  style: MqTextStyles.footnote.copyWith(
                    color: c.textTer,
                    fontFamily: MqTextStyles.monoFamily,
                    fontFamilyFallback: MqTextStyles.monoFallback,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
