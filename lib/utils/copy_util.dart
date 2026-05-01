import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../widgets/mq/mq_icons.dart';

/// Animated copy → check icon. Used inline next to mono values.
class AnimatedCopyIcon extends StatefulWidget {
  const AnimatedCopyIcon({super.key, required this.onCopy});
  final VoidCallback onCopy;

  @override
  State<AnimatedCopyIcon> createState() => _AnimatedCopyIconState();
}

class _AnimatedCopyIconState extends State<AnimatedCopyIcon> {
  bool _copied = false;

  void _handle() {
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
    widget.onCopy();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      onTap: _handle,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: _copied
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: Icon(MqIcons.copy, size: 16, color: c.textSec),
        firstCurve: Curves.easeInOut,
        secondChild: Icon(MqIcons.check, size: 16, color: c.success),
        secondCurve: Curves.easeInOut,
      ),
    );
  }
}

class _CopyToast extends StatefulWidget {
  const _CopyToast({required this.value, required this.onDismiss});
  final String value;
  final VoidCallback onDismiss;

  @override
  State<_CopyToast> createState() => _CopyToastState();
}

class _CopyToastState extends State<_CopyToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return SlideTransition(
      position: _slide,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MqRadius.lg),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: c.shadowLg,
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.successBg,
                borderRadius: BorderRadius.circular(MqRadius.sm),
              ),
              child: Icon(MqIcons.check, color: c.success, size: 18),
            ),
            const SizedBox(width: MqSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Copied to clipboard',
                    style: MqTextStyles.subhead.copyWith(
                      color: c.textPri,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.value,
                    style: MqTextStyles.footnote.copyWith(
                      color: c.textSec,
                      fontFamily: MqTextStyles.monoFamily,
                      fontFamilyFallback: MqTextStyles.monoFallback,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: MqSpacing.sm),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(MqRadius.xs + 2),
                ),
                child: Icon(MqIcons.xmark, color: c.textSec, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CopyToClipboardUtil {
  static OverlayEntry? _current;

  static void copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    _showCopyNotification(context, value);
  }

  static void _showCopyNotification(BuildContext context, String value) {
    _current?.remove();
    _current = null;

    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => Positioned(
        bottom: MediaQuery.of(ctx).padding.bottom + 20,
        left: 20,
        right: 20,
        child: _CopyToast(
          value: value,
          onDismiss: () {
            if (_current == entry) _current = null;
            entry.remove();
          },
        ),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}
