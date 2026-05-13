import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/mq_theme.dart';

/// Masquerade monogram: bracketed crossed hammer + quill. Source of truth
/// is `assets/brand/monogram-{light,dark}.svg`; the brand bg + hairline
/// frame are baked into the SVG. Theme switching picks the light vs dark
/// asset — no runtime recolor.
class MqMonogram extends StatelessWidget {
  const MqMonogram({super.key, this.size = 96});

  /// Side length of the square mark.
  final double size;

  @override
  Widget build(BuildContext context) {
    final String asset = context.mq.isDark
        ? 'assets/brand/monogram-dark.svg'
        : 'assets/brand/monogram-light.svg';
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
