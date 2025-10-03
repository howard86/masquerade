import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A stateful widget that handles the animated copy icon using AnimatedCrossFade
class AnimatedCopyIcon extends StatefulWidget {
  const AnimatedCopyIcon({super.key, required this.onCopy});

  final VoidCallback onCopy;

  @override
  State<AnimatedCopyIcon> createState() => _AnimatedCopyIconState();
}

class _AnimatedCopyIconState extends State<AnimatedCopyIcon> {
  bool _isCopied = false;

  void _handleCopy() {
    // Show tick icon temporarily
    setState(() {
      _isCopied = true;
    });

    // Revert back to copy icon after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });

    // Call the parent's copy handler
    widget.onCopy();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: _isCopied
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: const Icon(
          CupertinoIcons.doc_on_doc,
          size: 16,
          color: CupertinoColors.systemGrey,
        ),
        firstCurve: Curves.easeInOut,
        secondChild: const Icon(
          CupertinoIcons.check_mark,
          size: 16,
          color: CupertinoColors.systemGreen,
        ),
        secondCurve: Curves.easeInOut,
      ),
    );
  }
}

/// A Cupertino-styled notification overlay with slide animation
class _CupertinoNotificationOverlay extends StatefulWidget {
  const _CupertinoNotificationOverlay({
    required this.value,
    required this.onDismiss,
    this.autoDismissDelay = const Duration(seconds: 3),
  });

  final String value;
  final VoidCallback onDismiss;
  final Duration autoDismissDelay;

  @override
  State<_CupertinoNotificationOverlay> createState() =>
      _CupertinoNotificationOverlayState();
}

class _CupertinoNotificationOverlayState
    extends State<_CupertinoNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    // Start the slide-in animation
    _controller.forward();

    // Auto-dismiss after the specified delay
    Future.delayed(widget.autoDismissDelay, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    // Slide out animation
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.check_mark,
                color: CupertinoColors.systemGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Copied to clipboard',
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: CupertinoColors.label,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.value,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: CupertinoColors.systemGrey,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stateless widget that displays a timestamp row with label and copyable value
class TimestampRow extends StatelessWidget {
  const TimestampRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.secondaryLabel,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child: Row(
                    key: ValueKey(
                      value,
                    ), // Important: unique key for each value
                    children: [
                      Text(
                        value,
                        textAlign: TextAlign.left,
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.label,
                              fontSize: 15,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedCopyIcon(onCopy: () => _copyToClipboard(context, value)),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));

    // Show a notification-style overlay
    _showCopyNotification(context, value);
  }

  void _showCopyNotification(BuildContext context, String value) {
    // Remove any existing notification first
    if (_currentNotification != null) {
      _currentNotification!.remove();
      _currentNotification = null;
    }

    // Create an overlay entry for the notification
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        left: 20,
        right: 20,
        child: _CupertinoNotificationOverlay(
          value: value,
          onDismiss: () {
            overlayEntry.remove();
            _currentNotification = null;
          },
          autoDismissDelay: const Duration(seconds: 3),
        ),
      ),
    );

    // Store the overlay entry and insert it
    _currentNotification = overlayEntry;
    overlay.insert(overlayEntry);
  }

  // Static variable to track the current notification overlay
  static OverlayEntry? _currentNotification;
}
