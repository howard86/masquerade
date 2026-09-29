import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:masquerade/screens/detail/qr_scanner_route.dart';

class _FakeScannerPlatform extends MobileScannerPlatform {
  final StreamController<BarcodeCapture?> _barcodes =
      StreamController<BarcodeCapture?>.broadcast();
  final StreamController<TorchState> _torch =
      StreamController<TorchState>.broadcast();
  final StreamController<double> _zoom = StreamController<double>.broadcast();
  final Completer<MobileScannerViewAttributes> startResult =
      Completer<MobileScannerViewAttributes>();
  TorchState torchState = TorchState.off;
  int startCalls = 0;
  int stopCalls = 0;
  bool _disposed = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) {
    startCalls++;
    return startResult.future;
  }

  void completeStart() {
    startResult.complete(
      MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: torchState,
        size: const Size(200, 200),
        numberOfCameras: 1,
      ),
    );
  }

  void failStart(MobileScannerException error) {
    startResult.completeError(error);
  }

  void emitTorch(TorchState state) {
    torchState = state;
    _torch.add(state);
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF111111));

  @override
  Future<void> toggleTorch() async {
    emitTorch(torchState == TorchState.off ? TorchState.on : TorchState.off);
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _barcodes.close();
    await _torch.close();
    await _zoom.close();
  }
}

Widget _host({TextScaler textScaler = TextScaler.noScaling}) => CupertinoApp(
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: const QrScannerRoute(),
);

Future<_FakeScannerPlatform> _installPlatform(WidgetTester tester) async {
  final MobileScannerPlatform original = MobileScannerPlatform.instance;
  final _FakeScannerPlatform platform = _FakeScannerPlatform();
  MobileScannerPlatform.instance = platform;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    MobileScannerPlatform.instance = original;
  });
  return platform;
}

void main() {
  testWidgets('shows guidance and explicit torch states only when running', (
    WidgetTester tester,
  ) async {
    final _FakeScannerPlatform platform = await _installPlatform(tester);
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.bySemanticsLabel('Starting camera'), findsOneWidget);
    expect(find.text('Point camera at a QR code'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'flashlight')), findsNothing);

    platform.completeStart();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Starting camera'), findsNothing);
    expect(find.text('Point camera at a QR code'), findsOneWidget);
    final Finder torchOff = find.bySemanticsLabel('Turn flashlight on');
    expect(torchOff, findsOneWidget);
    expect(
      tester.getSemantics(torchOff).flagsCollection.isToggled,
      Tristate.isFalse,
    );

    await tester.tap(torchOff);
    await tester.pump();
    final Finder torchOn = find.bySemanticsLabel('Turn flashlight off');
    expect(torchOn, findsOneWidget);
    expect(
      tester.getSemantics(torchOn).flagsCollection.isToggled,
      Tristate.isTrue,
    );

    platform.emitTorch(TorchState.auto);
    await tester.pump();
    final Finder automatic = find.bySemanticsLabel('Toggle flashlight');
    expect(automatic, findsOneWidget);
    expect(
      tester.getSemantics(automatic).getSemanticsData().value,
      'Automatic',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(platform.stopCalls, 1);
    expect(find.text('Point camera at a QR code'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'flashlight')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.startCalls, 2);
    expect(find.text('Point camera at a QR code'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('announces camera errors without scannable chrome', (
    WidgetTester tester,
  ) async {
    final _FakeScannerPlatform platform = await _installPlatform(tester);
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(_host(textScaler: const TextScaler.linear(2)));
    await tester.pump();
    platform.failStart(
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    await tester.pumpAndSettle();

    const String message =
        'Camera permission denied. Enable it in Settings to scan QR codes.';
    final Finder error = find.bySemanticsLabel(message);
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Point camera at a QR code'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'flashlight')), findsNothing);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
