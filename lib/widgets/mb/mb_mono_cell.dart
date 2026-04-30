import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import '../../utils/copy_util.dart';
import 'mb_icons.dart';

/// Magic Box mono output cell. Uppercase caption + mono value + optional copy.
class MBMonoCell extends StatelessWidget {
  const MBMonoCell({
    super.key,
    required this.label,
    required this.value,
    this.copyable = true,
    this.accent = false,
    this.hint,
    this.large = false,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool accent;
  final String? hint;
  final bool large;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    final c = tokens.colors;

    final TextStyle valueStyle =
        (large ? MBTextStyles.monoLg : MBTextStyles.monoMd).copyWith(
          color: c.textPri,
        );
    final TextStyle labelStyle = MBTextStyles.sectionLabel.copyWith(
      color: accent ? c.accentInk : c.textSec,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? c.accentBg : c.surface2,
        borderRadius: BorderRadius.circular(MBRadius.md - 2),
        border: Border.all(
          color: accent ? c.accent.withValues(alpha: 0.2) : c.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MBSpacing.md,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(label, style: labelStyle)),
                if (copyable) _CopyButton(value: value, color: c.textTer),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: valueStyle, semanticsLabel: semanticsLabel),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: MBTextStyles.caption1.copyWith(
                  color: c.textTer,
                  fontFamily: MBTextStyles.monoFamily,
                  fontFamilyFallback: MBTextStyles.monoFallback,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.value, required this.color});
  final String value;
  final Color color;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _handle() {
    CopyToClipboardUtil.copyToClipboard(context, widget.value);
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mb;
    return Semantics(
      button: true,
      label: 'Copy ${widget.value}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handle,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _copied ? MBIcons.check : MBIcons.copy,
              key: ValueKey<bool>(_copied),
              size: 14,
              color: _copied ? tokens.colors.success : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
