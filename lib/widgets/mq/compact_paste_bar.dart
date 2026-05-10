import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import 'mq_button.dart';
import 'mq_icons.dart';
import 'mq_input.dart';

/// Two-stage hero composer. Idle state is a single-line input with paste
/// and scan icons in the trailing slot; once focused or holding content the
/// bar grows into a multiline composer and reveals a Paste / Clear button row.
class CompactPasteBar extends StatelessWidget {
  const CompactPasteBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onPaste,
    required this.onClear,
    required this.onScan,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final bool hasContent = controller.text.trim().isNotEmpty;
    final bool active = hasContent || focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: controller,
          focusNode: focusNode,
          placeholder: 'Paste timestamp, JSON, hex, base64, color…',
          multiline: active,
          minLines: active ? 2 : 1,
          maxLines: active ? 5 : 1,
          mono: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!active) ...<Widget>[
                _BarIconButton(
                  icon: MqIcons.paste,
                  label: 'Paste',
                  onTap: onPaste,
                  color: c.textSec,
                ),
                const SizedBox(width: 2),
              ],
              _BarIconButton(
                icon: MqIcons.qrCodeScan,
                label: 'Scan QR',
                onTap: onScan,
                color: c.textSec,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: MqMotion.normal,
          curve: hasContent ? MqMotion.reveal : MqMotion.dismiss,
          alignment: Alignment.topCenter,
          child: hasContent
              ? Padding(
                  padding: const EdgeInsets.only(top: MqSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: MqButton(
                          label: 'Paste',
                          icon: MqIcons.paste,
                          variant: MqButtonVariant.glass,
                          onPressed: onPaste,
                          full: true,
                        ),
                      ),
                      const SizedBox(width: MqSpacing.sm),
                      Expanded(
                        child: MqButton(
                          label: 'Clear',
                          icon: MqIcons.clear,
                          variant: MqButtonVariant.glass,
                          onPressed: onClear,
                          full: true,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
