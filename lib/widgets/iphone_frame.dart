import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../state/view_mode_controller.dart';
import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../utils/shell_layout.dart';
import 'mq/view_mode_toggle_button.dart';

/// Responsive wrapper. On a wide web window in desktop mode it renders [child]
/// full-bleed (the desktop shell supplies its own chrome). Otherwise it renders
/// [child] inside the hand-rolled iPhone silhouette on large viewports —
/// overlaying a "Desktop view" toggle when the desktop shell is available — or
/// directly on small viewports.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.child, this.isWebOverride});

  final Widget child;

  /// See `MyApp.isWebOverride`. Null in production → reads [kIsWeb].
  final bool? isWebOverride;

  static const double _maxScale = 2;

  // Inset (logical px) of the compact "Desktop view" chip within the frame.
  // Sits in the status strip beside the Dynamic Island and clear of the screen's
  // rounded top-right corner, so it reads as part of the device chrome.
  static const double _toggleTop = 16;
  static const double _toggleRight = 36;

  @override
  Widget build(BuildContext context) {
    final bool isWeb = isWebOverride ?? kIsWeb;
    final MqViewMode viewMode = ViewModeScope.of(context).mode;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MqShellLayout layout = resolveShellLayout(
          isWeb: isWeb,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          viewMode: viewMode,
        );
        // Desktop shell and small phones both render the child directly; only
        // the framed-mobile case wraps it in the silhouette.
        if (layout != MqShellLayout.framedMobile) return child;

        return _frame(
          context,
          constraints,
          showToggle: toggleAvailable(
            isWeb: isWeb,
            width: constraints.maxWidth,
          ),
        );
      },
    );
  }

  Widget _frame(
    BuildContext context,
    BoxConstraints constraints, {
    required bool showToggle,
  }) {
    final double innerW = constraints.maxWidth - MqSpacing.lg * 2;
    final double innerH = constraints.maxHeight - MqSpacing.lg * 2;
    final double fitH = innerH / IphoneFrame.logicalHeight;
    final double fitW = innerW / IphoneFrame.logicalWidth;
    final double scale = (fitH < fitW ? fitH : fitW).clamp(0.0, _maxScale);

    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      color: context.mq.colors.bg,
      child: Center(
        child: SizedBox(
          width: IphoneFrame.logicalWidth * scale,
          height: IphoneFrame.logicalHeight * scale,
          // The frame and its overlaid toggle scale together: FittedBox maps the
          // logical 393×852 silhouette onto the rendered size.
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: IphoneFrame.logicalWidth,
              height: IphoneFrame.logicalHeight,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: IphoneFrame(screen: child)),
                  if (showToggle)
                    const Positioned(
                      top: _toggleTop,
                      right: _toggleRight,
                      child: ViewModeToggleButton(
                        target: MqViewMode.desktop,
                        label: 'Desktop view',
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cupertino-only iPhone 16 Pro silhouette: titanium bezel, Dynamic Island,
/// home indicator. Injects synthetic safe-area padding matching the device so
/// wrapped screens' [SafeArea] respects the visual island and home bar.
class IphoneFrame extends StatelessWidget {
  const IphoneFrame({super.key, required this.screen});

  final Widget screen;

  static const double logicalWidth = 393;
  static const double logicalHeight = 852;

  static const double _outerRadius = 55;
  static const double _innerRadius = 45;
  static const double _bezelThickness = 10;
  static const double _safeAreaTop = 59;
  static const double _safeAreaBottom = 34;
  static const Color _bezelColor = Color(0xFF1F1F22);
  // 0.35 * 255 ≈ 89 (0x59); pre-computed so the BoxDecoration can be const.
  static const Color _shadowColor = Color(0x59000000);

  static const Key frameKey = ValueKey<String>('iphone_frame');
  static const Key screenKey = ValueKey<String>('iphone_frame_screen');
  static const Key dynamicIslandKey = ValueKey<String>(
    'iphone_frame_dynamic_island',
  );
  static const Key homeIndicatorKey = ValueKey<String>(
    'iphone_frame_home_indicator',
  );

  static const BorderRadius _outerBorderRadius = BorderRadius.all(
    Radius.circular(_outerRadius),
  );
  static const BorderRadius _innerBorderRadius = BorderRadius.all(
    Radius.circular(_innerRadius),
  );
  static const EdgeInsets _safeInsets = EdgeInsets.only(
    top: _safeAreaTop,
    bottom: _safeAreaBottom,
  );
  static const BoxDecoration _bezelDecoration = BoxDecoration(
    color: _bezelColor,
    borderRadius: _outerBorderRadius,
    boxShadow: <BoxShadow>[
      BoxShadow(blurRadius: 30, spreadRadius: 2, color: _shadowColor),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: frameKey,
      width: logicalWidth,
      height: logicalHeight,
      child: DecoratedBox(
        decoration: _bezelDecoration,
        child: Padding(
          padding: const EdgeInsets.all(_bezelThickness),
          child: ClipRRect(
            key: screenKey,
            borderRadius: _innerBorderRadius,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(padding: _safeInsets, viewPadding: _safeInsets),
                    child: screen,
                  ),
                ),
                const Positioned(
                  top: 11,
                  left: 0,
                  right: 0,
                  child: Center(child: _DynamicIsland()),
                ),
                const Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(child: _HomeIndicator()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: IphoneFrame.dynamicIslandKey,
      width: 126,
      height: 37,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.black,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: IphoneFrame.homeIndicatorKey,
      width: 134,
      height: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 0.65 * 255 ≈ 166 (0xA6).
          color: Color(0xA6FFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(2.5)),
        ),
      ),
    );
  }
}
