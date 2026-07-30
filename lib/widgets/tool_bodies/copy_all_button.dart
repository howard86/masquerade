import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../utils/copy_util.dart';
import '../mq/mq_button.dart';

/// Action-bar center button that copies a tool's full multi-output payload in
/// one tap. Mirrors the `MqMonoCell` copy idiom — selection haptic plus a brief
/// confirmation — but copies every output value at once.
///
/// Tool bodies build this from `actionBarCenter()` only when they have output,
/// so the bar hides it on blank/invalid input for free (the scaffold re-reads
/// the center slot after every parse).
class CopyAllButton extends StatefulWidget {
  const CopyAllButton({
    super.key,
    required this.payload,
    this.sensitive = false,
  });

  /// The newline-joined output values to write to the clipboard.
  final String payload;

  /// Whether [payload] should be masked in the copy-confirmation toast.
  final bool sensitive;

  @override
  State<CopyAllButton> createState() => _CopyAllButtonState();
}

class _CopyAllButtonState extends State<CopyAllButton> {
  bool _copied = false;

  void _handle() {
    CopyToClipboardUtil.copyToClipboard(
      context,
      widget.payload,
      sensitive: widget.sensitive,
    );
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MqButton(
      label: _copied ? 'Copied' : 'Copy all',
      variant: MqButtonVariant.glass,
      onPressed: _handle,
      full: true,
    );
  }
}
