import 'dart:ui';
import 'package:flutter/widgets.dart';

import '../../state/wallpaper_controller.dart';

/// Theme-aware premium generative wallpaper background for the desktop shell.
/// Supports Aurora Espresso, Parchment Minimalist, Cyber Glass, and Slate Solid.
class DesktopWallpaper extends StatelessWidget {
  const DesktopWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final MqWallpaperType type = WallpaperScope.of(context).type;

    return Stack(
      children: <Widget>[
        // Base Color
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: switch (type) {
                MqWallpaperType.auroraEspresso => const Color(0xFF100E0C),
                MqWallpaperType.parchmentMinimalist => const Color(0xFFFBF9F6),
                MqWallpaperType.cyberGlass => const Color(0xFF090710),
                MqWallpaperType.slateSolid => const Color(0xFF1E222B),
              },
            ),
          ),
        ),
        // Glowing Aurora / Geometric elements
        if (type == MqWallpaperType.auroraEspresso) ...<Widget>[
          Positioned(
            top: -200,
            left: -200,
            width: 600,
            height: 600,
            child: _GlowCircle(
              color: const Color(0xFFD48259).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: -300,
            right: -100,
            width: 700,
            height: 700,
            child: _GlowCircle(
              color: const Color(0xFF4A1521).withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 200,
            right: 100,
            width: 450,
            height: 450,
            child: _GlowCircle(
              color: const Color(0xFF7A4F30).withValues(alpha: 0.14),
            ),
          ),
        ] else if (type == MqWallpaperType.parchmentMinimalist) ...<Widget>[
          Positioned(
            top: 120,
            left: 180,
            width: 320,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFFE6DCD2).withValues(alpha: 0.45),
                    const Color(0xFFD2B48C).withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 150,
            width: 480,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(200),
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFFC8B9A6).withValues(alpha: 0.35),
                    const Color(0xFFE8D3C3).withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
        ] else if (type == MqWallpaperType.cyberGlass) ...<Widget>[
          Positioned(
            top: -120,
            right: -120,
            width: 650,
            height: 650,
            child: _GlowCircle(
              color: const Color(0xFF7B2CBF).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -120,
            width: 650,
            height: 650,
            child: _GlowCircle(
              color: const Color(0xFF00F5D4).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 180,
            left: 180,
            width: 280,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFF9B5DE5).withValues(alpha: 0.2),
                    const Color(0xFFF15BB5).withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
        // Soft Glassmorphic Blur for generative shapes
        if (type != MqWallpaperType.slateSolid)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
