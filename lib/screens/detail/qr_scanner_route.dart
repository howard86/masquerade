import 'dart:async';

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

class _QrScannerRouteState extends State<QrScannerRoute>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            if (!state.isRunning ||
                state.error != null ||
                torch == TorchState.unavailable) {
              return const SizedBox.shrink();
            }
            final bool automatic = torch == TorchState.auto;
            final bool active = torch == TorchState.on;
            return Semantics(
              button: true,
              toggled: automatic ? null : active,
              label: automatic
                  ? 'Toggle flashlight'
                  : active
                  ? 'Turn flashlight off'
                  : 'Turn flashlight on',
              value: automatic ? 'Automatic' : null,
              onTap: _controller.toggleTorch,
              excludeSemantics: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _controller.toggleTorch,
                child: Icon(
                  active ? MqIcons.flashFill : MqIcons.flash,
                  color: const Color(0xFFFFFFFF),
                ),
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
              placeholderBuilder: (BuildContext _) => const _ScannerLoading(),
              errorBuilder: (BuildContext _, MobileScannerException error) =>
                  _ScannerError(message: _describeError(error)),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder:
                  (
                    BuildContext context,
                    MobileScannerState state,
                    Widget? child,
                  ) {
                    if (!state.isRunning || state.error != null) {
                      return const SizedBox.shrink();
                    }
                    return Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: IgnorePointer(child: _ReticleOverlay()),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom:
                              MqSpacing.xl +
                              MediaQuery.paddingOf(context).bottom,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MqSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x99000000),
                                borderRadius: BorderRadius.circular(
                                  MqRadius.pill,
                                ),
                              ),
                              child: const Text(
                                'Point camera at a QR code',
                                style: TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

class _ScannerLoading extends StatelessWidget {
  const _ScannerLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Starting camera',
      excludeSemantics: true,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
            SizedBox(height: MqSpacing.md),
            Text(
              'Starting camera…',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
            ),
          ],
        ),
      ),
    );
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
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.lg),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
          ),
        ),
      ),
    );
  }
}
