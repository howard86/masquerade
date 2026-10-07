// Widget-level perf benchmarks (not under test/, so CI's `flutter test` skips
// them). Run: flutter test benchmark/widgets_bench_test.dart
//
// Each case prints `BENCH <name>: <value>` lines; min-of-N after warm-up.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/regex_parser.dart';
import 'package:masquerade/utils/regex_worker_native.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:masquerade/widgets/tool_bodies/bytes_body.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:masquerade/widgets/tool_bodies/qr_code_body.dart';
import 'package:masquerade/widgets/tool_bodies/regex_body.dart';
import 'package:masquerade/widgets/tool_bodies/url_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _n = 12;

void _report(String name, Object value) =>
    // ignore: avoid_print
    print('BENCH $name: $value');

/// Deterministic ASCII fixture of [size] chars that trips no sensitivity
/// regex (no `key=`, `KEY=value` line starts, JWTs or PEM headers).
String _fixture(int size) {
  const String chunk =
      'the quick brown fox jumps over the lazy dog 0123456789 ';
  final StringBuffer b = StringBuffer();
  while (b.length < size) {
    b.write(chunk);
  }
  return b.toString().substring(0, size);
}

/// Builds an uncompressed-filter, zlib-deflated RGBA PNG of [w]×[h].
Uint8List _png(int w, int h) {
  List<int> chunk(String type, List<int> data) {
    final List<int> td = <int>[...ascii.encode(type), ...data];
    final ByteData len = ByteData(4)..setUint32(0, data.length);
    final ByteData crc = ByteData(4)..setUint32(0, _crc32(td));
    return <int>[
      ...len.buffer.asUint8List(),
      ...td,
      ...crc.buffer.asUint8List(),
    ];
  }

  final ByteData ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  final Uint8List raw = Uint8List((w * 4 + 1) * h);
  for (int y = 0; y < h; y++) {
    final int row = y * (w * 4 + 1);
    for (int x = 0; x < w; x++) {
      final int p = row + 1 + x * 4;
      raw[p] = x & 0xFF;
      raw[p + 1] = y & 0xFF;
      raw[p + 2] = 0x80;
      raw[p + 3] = 0xFF;
    }
  }
  return Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', ihdr.buffer.asUint8List()),
    ...chunk('IDAT', zlib.encode(raw)),
    ...chunk('IEND', const <int>[]),
  ]);
}

int _crc32(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final int b in bytes) {
    c ^= b;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// Hosts [build] under the app's theme + history scopes at [width], with a
/// parent [StatefulBuilder] whose returned setter forces a rebuild of the
/// subtree (a fresh, non-const body instance each time).
Future<StateSetter> _host(
  WidgetTester tester,
  Widget Function() build, {
  double width = 640,
  Widget Function(Widget child)? wrap,
}) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late StateSetter rebuild;
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
                width: width,
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      rebuild = setState;
                      final Widget body = build();
                      return wrap == null ? body : wrap(body);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return rebuild;
}

Future<int> _minPumpMicros(WidgetTester tester, void Function() dirty) async {
  int best = 1 << 62;
  for (int i = 0; i < _n + 3; i++) {
    dirty();
    final Stopwatch sw = Stopwatch()..start();
    await tester.pump();
    sw.stop();
    if (i >= 3 && sw.elapsedMicroseconds < best) {
      best = sw.elapsedMicroseconds;
    }
  }
  return best;
}

void main() {
  // benchmark/ is outside test/, so the analyzer doesn't see a test context.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ── Item 1: Base64 image preview decode size + re-parse retention ─────────
  testWidgets('base64 image preview: decoded cache bytes', (tester) async {
    imageCache.clear();
    imageCache.clearLiveImages();
    final String b64 = base64Encode(_png(2000, 2000));
    await _host(tester, () => const Base64Body(), width: 640);
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, b64);
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> settleDecode() async {
      for (int i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    await settleDecode();
    _report(
      'b64-image cache bytes after 1st decode',
      imageCache.currentSizeBytes,
    );
    // Re-parse the same input (URL-safe off→on→off) — content is unchanged.
    await tester.tap(find.text('Strip padding'));
    await tester.pump();
    await settleDecode();
    await tester.tap(find.text('Strip padding'));
    await tester.pump();
    await settleDecode();
    _report(
      'b64-image cache bytes after 2 re-parses',
      imageCache.currentSizeBytes,
    );
    _report(
      'b64-image cache count after 2 re-parses',
      imageCache.currentSize + imageCache.liveImageCount,
    );
  });

  // ── Item 2: per-build sensitivity scans (parent rebuild, 1 MB input) ──────
  testWidgets('base64 encode 1MB: parent-rebuild pump', (tester) async {
    final StateSetter rebuild = await _host(tester, () => Base64Body());
    await tester.enterText(find.byType(EditableText).last, _fixture(1 << 20));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    _report(
      'base64 1MB rebuild pump us',
      await _minPumpMicros(tester, () => rebuild(() {})),
    );
  });

  testWidgets('url encode 1MB: parent-rebuild pump', (tester) async {
    final StateSetter rebuild = await _host(tester, () => UrlBody());
    await tester.enterText(find.byType(EditableText).last, _fixture(1 << 20));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    _report(
      'url 1MB rebuild pump us',
      await _minPumpMicros(tester, () => rebuild(() {})),
    );
  });

  testWidgets('bytes decode 256KB: parent-rebuild pump', (tester) async {
    final StateSetter rebuild = await _host(tester, () => BytesBody());
    final String ints = List<String>.generate(
      64 * 1024,
      (int i) => '${97 + i % 26}',
    ).join(' ');
    await tester.enterText(find.byType(EditableText).last, ints);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    _report(
      'bytes decode ${ints.length}B rebuild pump us',
      await _minPumpMicros(tester, () => rebuild(() {})),
    );
  });

  testWidgets('MqMonoCell 1MB: parent-rebuild pump', (tester) async {
    final String value = _fixture(1 << 20);
    final StateSetter rebuild = await _host(
      tester,
      () => MqMonoCell(label: 'Out', value: value),
      width: 390,
    );
    _report(
      'monocell 1MB rebuild pump us',
      await _minPumpMicros(tester, () => rebuild(() {})),
    );
  });

  test('containsSensitiveArtifact 1MB scan cost', () {
    final String v = _fixture(1 << 20);
    int best = 1 << 62;
    for (int i = 0; i < _n + 3; i++) {
      final Stopwatch sw = Stopwatch()..start();
      SensitiveDataPolicy.containsSensitiveArtifact(v);
      sw.stop();
      if (i >= 3 && sw.elapsedMicroseconds < best) {
        best = sw.elapsedMicroseconds;
      }
    }
    _report('scan 1MB us', best);
  });

  testWidgets('qr 2KB: ECC toggle pump (action-bar rebind)', (tester) async {
    await _host(tester, () => const QrCodeBody(), width: 640);
    await tester.enterText(find.byType(EditableText).last, _fixture(2000));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    bool m = false;
    int best = 1 << 62;
    for (int i = 0; i < _n + 3; i++) {
      m = !m;
      await tester.tap(find.text(m ? 'M' : 'L'));
      final Stopwatch sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      if (i >= 3 && sw.elapsedMicroseconds < best) {
        best = sw.elapsedMicroseconds;
      }
    }
    _report('qr 2KB ecc toggle pump us', best);
  });

  // ── Item 3: MqMonoCell layout at 1 MB (resize relayout) ───────────────────
  testWidgets('MqMonoCell 1MB: resize relayout pump', (tester) async {
    final String value = _fixture(1 << 20);
    double width = 390;
    late StateSetter rebuild;
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: MqMonoCell(label: 'Out', value: value),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _report(
      'monocell 1MB resize pump us',
      await _minPumpMicros(
        tester,
        () => rebuild(() => width = width == 390 ? 391 : 390),
      ),
    );
  });

  // ── Item 4: regex worker spawn cost + supersede ───────────────────────────
  test('regex worker: sequential runs/sec (trivial pattern)', () async {
    Future<void> once() => runRegexWorker(
      pattern: r'\d+',
      input: 'abc 123 def 456',
      caseSensitive: true,
      multiLine: false,
      dotAll: false,
      unicode: true,
      timeLimit: const Duration(seconds: 5),
    );
    for (int i = 0; i < 5; i++) {
      await once();
    }
    int best = 1 << 62;
    for (int r = 0; r < _n; r++) {
      final Stopwatch sw = Stopwatch()..start();
      for (int i = 0; i < 20; i++) {
        await once();
      }
      sw.stop();
      if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
    }
    _report('regex runs/sec (one-shot)', (20 * 1e6 / best).round());
  });

  for (final int stale in <int>[4, 8]) {
    test('regex worker: latest-run latency after $stale superseded '
        'catastrophic runs', () async {
      final String evil = '${'a' * 30}!';
      int best = 1 << 62;
      for (int r = 0; r < 3; r++) {
        final List<Future<RegexResult>> pending = <Future<RegexResult>>[
          for (int i = 0; i < stale; i++)
            runRegexWorker(
              pattern: r'(a+)+$',
              input: evil,
              caseSensitive: true,
              multiLine: false,
              dotAll: false,
              unicode: true,
              timeLimit: const Duration(milliseconds: 500),
            ),
        ];
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final Stopwatch sw = Stopwatch()..start();
        await runRegexWorker(
          pattern: r'\d+',
          input: 'abc 123',
          caseSensitive: true,
          multiLine: false,
          dotAll: false,
          unicode: true,
          timeLimit: const Duration(seconds: 5),
        );
        sw.stop();
        if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
        await Future.wait(pending);
      }
      _report('regex latest-run latency us (one-shot, $stale stale)', best);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('regex session: sequential runs/sec (trivial pattern)', () async {
    final RegexWorkerSession session = RegexWorkerSession();
    addTearDown(session.dispose);
    Future<void> once() => session.run(
      pattern: r'\d+',
      input: 'abc 123 def 456',
      caseSensitive: true,
      multiLine: false,
      dotAll: false,
      unicode: true,
      timeLimit: const Duration(seconds: 5),
    );
    for (int i = 0; i < 5; i++) {
      await once();
    }
    int best = 1 << 62;
    for (int r = 0; r < _n; r++) {
      final Stopwatch sw = Stopwatch()..start();
      for (int i = 0; i < 20; i++) {
        await once();
      }
      sw.stop();
      if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
    }
    _report('regex runs/sec (session)', (20 * 1e6 / best).round());
  });

  for (final int stale in <int>[4, 8, 28]) {
    test('regex session: latest-run latency after $stale superseded '
        'catastrophic runs', () async {
      final RegexWorkerSession session = RegexWorkerSession();
      addTearDown(session.dispose);
      final String evil = '${'a' * 30}!';
      int best = 1 << 62;
      int maxLive = 0;
      for (int r = 0; r < 3; r++) {
        final List<Future<RegexResult>> pending = <Future<RegexResult>>[];
        for (int i = 0; i < stale; i++) {
          pending.add(
            session.run(
              pattern: r'(a+)+$',
              input: evil,
              caseSensitive: true,
              multiLine: false,
              dotAll: false,
              unicode: true,
              timeLimit: const Duration(milliseconds: 500),
            ),
          );
          // Let the run reach the isolate so the next one must kill it.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (session.liveWorkers > maxLive) maxLive = session.liveWorkers;
        }
        final Stopwatch sw = Stopwatch()..start();
        await session.run(
          pattern: r'\d+',
          input: 'abc 123',
          caseSensitive: true,
          multiLine: false,
          dotAll: false,
          unicode: true,
          timeLimit: const Duration(seconds: 5),
        );
        sw.stop();
        if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
        await Future.wait(pending);
      }
      _report('regex latest-run latency us (session, $stale stale)', best);
      _report('regex max live isolates (session, $stale stale)', maxLive);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  // ── Item 5: regex settings saves per keystroke ────────────────────────────
  testWidgets('regex: settings saves while typing 20 chars', (tester) async {
    int saves = 0;
    await _host(
      tester,
      () => RegexBody(
        runner:
            ({
              required String pattern,
              required String input,
              bool caseSensitive = true,
              bool multiLine = false,
              bool dotAll = false,
              bool unicode = true,
            }) async => RegexTester.run(pattern: pattern, input: input),
      ),
      wrap: (Widget child) => MobileSessionRouteScope(
        addNext: false,
        protectedSession: false,
        onSettingsChanged: (_) => saves++,
        child: child,
      ),
    );
    saves = 0;
    final Finder field = find.byKey(const ValueKey<String>('regex-pattern'));
    String text = '';
    for (int i = 0; i < 20; i++) {
      text += 'a';
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 300));
    _report('regex settings saves per 20 keystrokes', saves);
  });
}
