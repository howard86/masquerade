import 'package:flutter/cupertino.dart';

/// Responsive wrapper that renders [child] inside a hand-rolled iPhone 16 Pro
/// silhouette on screens larger than the device's logical size, and renders
/// [child] directly otherwise.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double iphoneWidth = 393;
        const double iphoneHeight = 852;

        if (constraints.maxWidth > iphoneWidth + 100 ||
            constraints.maxHeight > iphoneHeight + 200) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            color: CupertinoColors.systemGrey6,
            child: Center(child: IphoneFrame(screen: child)),
          );
        }

        return child;
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

  static const double _logicalWidth = 393;
  static const double _logicalHeight = 852;
  static const double _outerRadius = 55;
  static const double _innerRadius = 45;
  static const double _bezelThickness = 10;
  static const double _islandWidth = 126;
  static const double _islandHeight = 37;
  static const double _islandRadius = 20;
  static const double _islandTopOffset = 11;
  static const double _homeBarWidth = 134;
  static const double _homeBarHeight = 5;
  static const double _homeBarBottomOffset = 8;
  static const double _safeAreaTop = 59;
  static const double _safeAreaBottom = 34;
  static const Color _bezelColor = Color(0xFF1F1F22);

  @override
  Widget build(BuildContext context) {
    final MediaQueryData base = MediaQuery.of(context);
    return SizedBox(
      key: const ValueKey<String>('iphone_frame'),
      width: _logicalWidth,
      height: _logicalHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bezelColor,
          borderRadius: BorderRadius.circular(_outerRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              blurRadius: 30,
              spreadRadius: 2,
              color: CupertinoColors.black.withValues(alpha: 0.35),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(_bezelThickness),
          child: ClipRRect(
            key: const ValueKey<String>('iphone_frame_screen'),
            borderRadius: BorderRadius.circular(_innerRadius),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: MediaQuery(
                    data: base.copyWith(
                      padding: const EdgeInsets.only(
                        top: _safeAreaTop,
                        bottom: _safeAreaBottom,
                      ),
                      viewPadding: const EdgeInsets.only(
                        top: _safeAreaTop,
                        bottom: _safeAreaBottom,
                      ),
                    ),
                    child: screen,
                  ),
                ),
                const Positioned(
                  top: _islandTopOffset,
                  left: 0,
                  right: 0,
                  child: Center(child: _DynamicIsland()),
                ),
                const Positioned(
                  bottom: _homeBarBottomOffset,
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
    return Container(
      key: const ValueKey<String>('iphone_frame_dynamic_island'),
      width: IphoneFrame._islandWidth,
      height: IphoneFrame._islandHeight,
      decoration: BoxDecoration(
        color: CupertinoColors.black,
        borderRadius: BorderRadius.circular(IphoneFrame._islandRadius),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('iphone_frame_home_indicator'),
      width: IphoneFrame._homeBarWidth,
      height: IphoneFrame._homeBarHeight,
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(IphoneFrame._homeBarHeight / 2),
      ),
    );
  }
}
