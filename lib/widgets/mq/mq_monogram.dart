import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/mq_theme.dart';

/// Masquerade monogram: bracketed crossed hammer + quill. Geometry mirrors
/// `assets/brand/monogram-{light,dark}.svg` (kept for native splash/icon
/// generation); the brand bg + hairline frame are drawn here too. Theme
/// switching picks the light vs dark palette — no runtime recolor.
class MqMonogram extends StatelessWidget {
  const MqMonogram({super.key, this.size = 96});

  /// Side length of the square mark.
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.mq.isDark;
    return CustomPaint(
      size: Size.square(size),
      painter: _MonogramPainter(dark: dark),
    );
  }
}

class _MonogramPainter extends CustomPainter {
  const _MonogramPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final Color bg = dark ? const Color(0xFF14110D) : const Color(0xFFFAF7F2);
    final Color frame = dark
        ? const Color(0x47F2EBDC) // 0.28 opacity
        : const Color(0x3D1B1813); // 0.24 opacity
    final Color ink = dark ? const Color(0xFFE0B872) : const Color(0xFF8B2635);

    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);

    canvas.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()..color = bg);
    canvas.drawRect(
      const Rect.fromLTWH(3, 3, 1018, 1018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = frame,
    );

    final Paint bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = ink;
    canvas.drawPath(
      Path()
        ..moveTo(334, 296)
        ..lineTo(248, 296)
        ..lineTo(248, 728)
        ..lineTo(334, 728),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(690, 296)
        ..lineTo(776, 296)
        ..lineTo(776, 728)
        ..lineTo(690, 728),
      bracket,
    );

    final Paint fill = Paint()..color = ink;

    // Hammer.
    canvas.save();
    canvas.translate(512, 512);
    canvas.rotate(math.pi / 4);
    canvas.translate(-512, -512);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(447, 372, 130, 78),
        const Radius.circular(14),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(497, 440, 30, 212),
        const Radius.circular(15),
      ),
      fill,
    );
    canvas.restore();

    // Quill.
    canvas.save();
    canvas.translate(512, 512);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-512, -512);
    canvas.drawPath(
      Path()
        ..moveTo(512, 372)
        ..cubicTo(468, 452, 464, 548, 500, 622)
        ..cubicTo(506, 638, 518, 638, 524, 622)
        ..cubicTo(560, 548, 556, 452, 512, 372)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(502, 616)
        ..lineTo(522, 616)
        ..lineTo(512, 686)
        ..close(),
      fill,
    );
    canvas.drawLine(
      const Offset(512, 396),
      const Offset(512, 618),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = bg,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MonogramPainter old) => old.dark != dark;
}
