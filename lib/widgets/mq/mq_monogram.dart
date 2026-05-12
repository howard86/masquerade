import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Masquerade monogram: Plex Mono brackets framing a Plex Serif italic
/// `M.`. Source of truth for the bracket+letterform composition is
/// `assets/brand/monogram-{light,dark}.svg`; this widget renders the
/// runtime equivalent so the mark theme-switches without an asset swap.
class MqMonogram extends StatelessWidget {
  const MqMonogram({
    super.key,
    this.size = 96,
    this.background,
    this.foreground,
    this.showFrame = true,
  });

  /// Side length of the square frame. The `[ M. ]` glyph cluster sizes off
  /// of this so the mark stays optically centered at every callsite.
  final double size;
  final Color? background;
  final Color? foreground;

  /// When false, draws only the bracket+letter cluster (no surrounding
  /// square + hairline). Used by the splash composition where the
  /// monogram already sits inside an explicit panel.
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color bg = background ?? c.surface;
    final Color fg = foreground ?? c.accent;
    final Color border = c.borderStrong;
    final double letterSize = size * 0.50;
    final double bracketSize = size * 0.38;
    final TextStyle bracket = MqTextStyles.monoLg.copyWith(
      color: fg,
      fontSize: bracketSize,
      height: 1.0,
      fontWeight: FontWeight.w500,
    );
    final TextStyle letter = MqTextStyles.display.copyWith(
      color: fg,
      fontStyle: FontStyle.italic,
      fontSize: letterSize,
      height: 1.0,
    );
    final Widget cluster = Padding(
      padding: EdgeInsets.only(top: size * 0.05),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '[ ', style: bracket),
            TextSpan(text: 'M.', style: letter),
            TextSpan(text: ' ]', style: bracket),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
    if (!showFrame) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: cluster),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.06),
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: cluster,
    );
  }
}
