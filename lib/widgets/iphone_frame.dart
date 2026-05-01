import 'package:flutter/cupertino.dart';

import '../theme/mb_metrics.dart';
import '../theme/mb_theme.dart';

/// Responsive wrapper that renders [child] inside a hand-rolled iPhone 16 Pro
/// silhouette on screens larger than the device's logical size, and renders
/// [child] directly otherwise.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.child});

  final Widget child;

  static const double _maxScale = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth <= IphoneFrame.logicalWidth + 100 &&
            constraints.maxHeight <= IphoneFrame.logicalHeight + 200) {
          return child;
        }

        final double innerW = constraints.maxWidth - MBSpacing.lg * 2;
        final double innerH = constraints.maxHeight - MBSpacing.lg * 2;
        final double fitH = innerH / IphoneFrame.logicalHeight;
        final double fitW = innerW / IphoneFrame.logicalWidth;
        final double scale = (fitH < fitW ? fitH : fitW).clamp(0.0, _maxScale);

        return Container(
          padding: const EdgeInsets.all(MBSpacing.lg),
          color: context.mb.colors.bg,
          child: Center(
            child: SizedBox(
              width: IphoneFrame.logicalWidth * scale,
              height: IphoneFrame.logicalHeight * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: IphoneFrame(screen: child),
              ),
            ),
          ),
        );
      },
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
