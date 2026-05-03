import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_typography.dart';
import '../../widgets/mq/mq_icons.dart';

/// Pushes the camera scanner. Resolves to the decoded payload, or `null` on
/// cancel / dismissal.
Future<String?> pushQrScanner(BuildContext context) =>
    Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        fullscreenDialog: true,
        builder: (BuildContext _) => const QrScannerRoute(),
      ),
    );

/// Full-screen camera route. Pops the first decoded QR/barcode payload back
/// to the caller as a [String]. Returns `null` when the user cancels.
class QrScannerRoute extends StatefulWidget {
  const QrScannerRoute({super.key});

  @override
  State<QrScannerRoute> createState() => _QrScannerRouteState();
}

class _QrScannerRouteState extends State<QrScannerRoute> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final Barcode b in capture.barcodes) {
      final String? value = b.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xCC000000),
        border: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
        ),
        middle: Text(
          'Scan QR',
          style: MqTextStyles.headline.copyWith(color: const Color(0xFFFFFFFF)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
        trailing: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (BuildContext _, MobileScannerState state, Widget? child) {
            final TorchState torch = state.torchState;
            if (torch == TorchState.unavailable) {
              return const SizedBox.shrink();
            }
            final bool on = torch == TorchState.on;
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _controller.toggleTorch,
              child: Icon(
                on ? MqIcons.flashFill : MqIcons.flash,
                color: const Color(0xFFFFFFFF),
              ),
            );
          },
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (BuildContext _, MobileScannerException error) =>
                  _ScannerError(message: _describeError(error)),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _ReticleOverlay())),
          Positioned(
            left: 0,
            right: 0,
            bottom: MqSpacing.xl,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MqSpacing.md,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(MqRadius.pill),
                ),
                child: const Text(
                  'Point camera at a QR code',
                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _describeError(MobileScannerException e) {
    return switch (e.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission denied. Enable it in Settings to scan QR codes.',
      MobileScannerErrorCode.unsupported =>
        'This device does not support camera scanning.',
      _ => e.errorDetails?.message ?? 'Camera error.',
    };
  }
}

class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints constraints) {
        final double side = (constraints.biggest.shortestSide * 0.7).clamp(
          180.0,
          320.0,
        );
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ReticlePainter(side: side),
          ),
        );
      },
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter({required this.side});

  final double side;

  static const Color _dim = Color(0x66000000);
  static const Color _stroke = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final RRect hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: full.center, width: side, height: side),
      const Radius.circular(MqRadius.lg),
    );

    final Path dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(hole);
    canvas.drawPath(dim, Paint()..color = _dim);

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _stroke,
    );
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.side != side;
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
        ),
      ),
    );
  }
}
