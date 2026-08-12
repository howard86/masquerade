import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'
    as ui
    show
        Canvas,
        Color,
        FrameTiming,
        Image,
        ImageByteFormat,
        Paint,
        PictureRecorder,
        Rect;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: base64_image_memory_benchmark <output.json>');
    exitCode = 64;
    return;
  }
  assert(false, 'Run with flutter run --profile.');

  final LiveTestWidgetsFlutterBinding binding =
      LiveTestWidgetsFlutterBinding.ensureInitialized()
        ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final Uint8List compressed = await _png(1242, 2208);
  final String encoded = base64Encode(compressed);
  final ImageCache cache = PaintingBinding.instance.imageCache;
  cache
    ..clear()
    ..clearLiveImages();

  late Map<String, Object?> result;
  await benchmarkWidgets((WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    final int rssBefore = ProcessInfo.currentRss;
    final List<ui.FrameTiming> timings = <ui.FrameTiming>[];
    void record(List<ui.FrameTiming> values) => timings.addAll(values);
    binding.addTimingsCallback(record);
    final Stopwatch stopwatch = Stopwatch()..start();

    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: CupertinoPageScaffold(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 640,
                  child: SingleChildScrollView(
                    child: Base64Body(initialInput: encoded),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    stopwatch.stop();
    binding.removeTimingsCallback(record);

    final RawImage raw = tester.widget<RawImage>(find.byType(RawImage));
    final Rect logicalRect = tester.getRect(find.byType(Image));
    final int rssAfter = ProcessInfo.currentRss;
    result = <String, Object?>{
      'schema': 1,
      'metric': 'base64_preview_decoded_cache_bytes',
      'lower_is_better': true,
      'environment': <String, Object?>{
        'device': 'macos-arm64',
        'dart': Platform.version.split(' ').first,
        'surface': '1024x1400',
        'devicePixelRatio': tester.view.devicePixelRatio,
        'input': 'generated 1242x2208 PNG',
        'compressedBytes': compressed.length,
      },
      'decodedCacheBytes': cache.currentSizeBytes,
      'cacheEntries': cache.currentSize,
      'liveImages': cache.liveImageCount,
      'rssBefore': rssBefore,
      'rssAfter': rssAfter,
      'rssDelta': rssAfter - rssBefore,
      'renderUs': stopwatch.elapsedMicroseconds,
      'buildUs': timings
          .map((ui.FrameTiming value) => value.buildDuration.inMicroseconds)
          .toList(growable: false),
      'rasterUs': timings
          .map((ui.FrameTiming value) => value.rasterDuration.inMicroseconds)
          .toList(growable: false),
      'decodedWidth': raw.image?.width,
      'decodedHeight': raw.image?.height,
      'logicalWidth': logicalRect.width,
      'logicalHeight': logicalRect.height,
      'errorVisible': find
          .text('Could not render image.')
          .evaluate()
          .isNotEmpty,
    };
  });

  final String encodedResult = const JsonEncoder.withIndent(
    ' ',
  ).convert(result);
  if (args[0] == '-') {
    stdout.writeln(encodedResult);
  } else {
    File(args[0]).writeAsStringSync('$encodedResult\n');
  }
  if (result['errorVisible'] == true || result['decodedWidth'] == null) {
    exitCode = 1;
  }
  exit(exitCode);
}

Future<Uint8List> _png(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF8B2635),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData data = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return data.buffer.asUint8List();
}
