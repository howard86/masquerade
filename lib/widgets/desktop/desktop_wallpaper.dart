import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';

// TODO(phase5): swap gradient for bundled still-life wallpaper images.

/// Theme-aware gradient background for the desktop content area, painted behind
/// the canvas. Light: warm cream→parchment; Dark: charcoal→deep-oxblood.
class DesktopWallpaper extends StatelessWidget {
  const DesktopWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[c.bg, Color.lerp(c.bg, c.surface, 0.6)!],
        ),
      ),
    );
  }
}
