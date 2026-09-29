// Desktop OS rendering benchmarks. Not under test/, so CI's `flutter test`
// skips it; run with `flutter test benchmark/desktop_bench_test.dart`.
//
// Widget-level measurements (debug-mode flutter_test, no rasterizer):
//  * element rebuilds per drag / pan tick, bucketed by widget type,
//  * RenderObjects painted per tick (repaint-boundary proxy for raster cost),
//  * BackdropFilter layers in the composited layer tree,
//  * wall-clock `tester.pump()` per tick (min / median),
//  * menubar rebuilds per simulated hour,
//  * controller-level persistence / accessor timings (Stopwatch, min-of-N).
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> _openIds = <String>[
  'json',
  'base64',
  'uuid',
  'timestamp',
  'hash',
];
const Set<String> _bodyTypes = <String>{
  'JSONBody',
  'Base64Body',
  'UuidBody',
  'TimestampBody',
  'HashBody',
};
const int _warmTicks = 20;
const int _ticks = 60;

class _Counts {
  final Map<String, int> builds = <String, int>{};
  int totalBuilds = 0;
  int painted = 0;
  int dotGridPaints = 0;
  int backdropPaints = 0;

  void reset() {
    builds.clear();
    totalBuilds = 0;
    painted = 0;
    dotGridPaints = 0;
    backdropPaints = 0;
  }

  int of(String bucket) => builds[bucket] ?? 0;
}

final _Counts _counts = _Counts();

String _bucket(Widget w) {
  final String name = w.runtimeType.toString();
  if (_bodyTypes.contains(name)) return 'body';
  if (name == '_LauncherTile') return 'launcherTile';
  if (name == 'DesktopMenubar') return 'menubar';
  if (name == 'MenubarClock') return 'clock';
  if (name == 'DesktopDock') return 'dock';
  if (name == 'ToolCardFrame') return 'frame';
  if (name == 'DesktopIconGrid') return 'iconGrid';
  return 'other';
}

void _install() {
  debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
    _counts.totalBuilds++;
    final String b = _bucket(e.widget);
    _counts.builds[b] = (_counts.builds[b] ?? 0) + 1;
  };
  debugOnProfilePaint = (RenderObject ro) {
    _counts.painted++;
    if (ro is RenderCustomPaint &&
        ro.painter.runtimeType.toString() == '_DotGridPainter') {
      _counts.dotGridPaints++;
    }
    if (ro is RenderBackdropFilter) _counts.backdropPaints++;
  };
}

void _uninstall() {
  debugOnRebuildDirtyWidget = null;
  debugOnProfilePaint = null;
}

Future<CanvasController> _pumpDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
  final CanvasController c = tester
      .widget<DesktopMenubar>(find.byType(DesktopMenubar))
      .controller;
  for (final String id in _openIds) {
    c.openTool(UtilityCatalog.byId(id));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  expect(find.byType(ToolCardFrame), findsNWidgets(_openIds.length));
  return c;
}

String _stats(List<int> us) {
  final List<int> s = List<int>.of(us)..sort();
  return 'min ${s.first} us, median ${s[s.length ~/ 2]} us';
}

Future<void> _runGesture(
  WidgetTester tester,
  String label,
  Offset start,
) async {
  final TestGesture g = await tester.startGesture(start);
  // Get past the pan slop so every measured tick is a real drag update.
  await g.moveBy(const Offset(30, 0));
  await tester.pump();
  for (int i = 0; i < _warmTicks; i++) {
    await g.moveBy(Offset(i.isEven ? 3 : -3, 1));
    await tester.pump();
  }
  final List<int> pumpUs = <int>[];
  _install();
  _counts.reset();
  for (int i = 0; i < _ticks; i++) {
    await g.moveBy(Offset(i.isEven ? 3 : -3, i.isEven ? 1 : -1));
    final Stopwatch sw = Stopwatch()..start();
    await tester.pump();
    pumpUs.add(sw.elapsedMicroseconds);
  }
  _uninstall();
  await g.up();
  await tester.pump(const Duration(milliseconds: 400));

  String per(int n) => (n / _ticks).toStringAsFixed(2);
  // ignore: avoid_print
  print(
    '[$label] per tick: bodies ${per(_counts.of('body'))}, '
    'launcherTiles ${per(_counts.of('launcherTile'))}, '
    'iconGrid ${per(_counts.of('iconGrid'))}, '
    'menubar ${per(_counts.of('menubar'))}, '
    'dock ${per(_counts.of('dock'))}, '
    'frames ${per(_counts.of('frame'))}, '
    'allElements ${per(_counts.totalBuilds)}, '
    'renderObjectsPainted ${per(_counts.painted)}, '
    'dotGridPaints ${per(_counts.dotGridPaints)}, '
    'backdropPaints ${per(_counts.backdropPaints)}; '
    'pump ${_stats(pumpUs)}',
  );
}

int _countLayers<T extends Layer>(Layer root) {
  int n = 0;
  void walk(Layer l) {
    if (l is T) n++;
    if (l is ContainerLayer) {
      Layer? child = l.firstChild;
      while (child != null) {
        walk(child);
        child = child.nextSibling;
      }
    }
  }

  walk(root);
  return n;
}

double _minOf(int n, void Function() body, {int reps = 1}) {
  double best = double.infinity;
  for (int i = 0; i < n; i++) {
    final Stopwatch sw = Stopwatch()..start();
    body();
    final double us = sw.elapsedMicroseconds / reps;
    if (us < best) best = us;
  }
  return best;
}

String _kb(int kb) =>
    List<String>.generate(kb * 16, (int i) => 'line-$i-abcdefghij\n').join();

void main() {
  setUp(
    // ignore: invalid_use_of_visible_for_testing_member
    () => SharedPreferences.setMockInitialValues(<String, Object>{}),
  );

  testWidgets('drag window: 5 windows open', (WidgetTester tester) async {
    await _pumpDesktop(tester);
    final Offset top = tester.getTopLeft(find.byType(ToolCardFrame).last);
    await _runGesture(tester, 'drag', top + const Offset(180, 18));
  });

  testWidgets('pan canvas: 5 windows open', (WidgetTester tester) async {
    await _pumpDesktop(tester);
    await _runGesture(tester, 'pan', const Offset(900, 820));
  });

  testWidgets('layer tree: backdrop filters', (WidgetTester tester) async {
    await _pumpDesktop(tester);
    final Layer root = tester.binding.renderViews.first.debugLayer!;
    // ignore: avoid_print
    print(
      '[layers] BackdropFilterLayer ${_countLayers<BackdropFilterLayer>(root)}, '
      'PictureLayer ${_countLayers<PictureLayer>(root)}, '
      'OffsetLayer ${_countLayers<OffsetLayer>(root)}',
    );
  });

  testWidgets('menubar rebuilds per simulated hour', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    _install();
    _counts.reset();
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(seconds: 30));
    }
    _uninstall();
    // ignore: avoid_print
    print(
      '[clock] per hour: menubar ${_counts.of('menubar')}, '
      'clock ${_counts.of('clock')}, '
      'allElements ${_counts.totalBuilds}',
    );
  });

  group('controller', () {
    test('link emit + focus persistence', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController c = CanvasController(prefs: prefs);
      final List<int> ids = <int>[
        for (final String id in _openIds)
          c.openTool(UtilityCatalog.byId(id), seed: _kb(10)),
      ];
      c.linkCards(ids[0], ids[1], type: ContentType.text);
      final LinkChannel ch = c.channelForCard(ids[0])!;
      final String big = _kb(10);
      int n = 0;
      int sink = 0;
      final double emitUs = _minOf(10, () {
        for (int i = 0; i < 100; i++) {
          ch.emit('$big${n++}');
        }
      }, reps: 100);
      final double focusUs = _minOf(10, () {
        for (int i = 0; i < 100; i++) {
          c.focus(ids[i % 2]);
        }
      }, reps: 100);
      final double snapshotUs = _minOf(10, () {
        for (int i = 0; i < 20; i++) {
          sink += jsonEncode(c.toJson()).length;
        }
      }, reps: 20);
      c.dispose();
      // ignore: invalid_use_of_visible_for_testing_member
      final int writes = c.debugPersistWrites;
      // ignore: avoid_print
      print(
        '[persist] snapshot ${snapshotUs.toStringAsFixed(1)} us/toJson+encode, '
        'writes $writes, '
        'emit ${emitUs.toStringAsFixed(1)} us/emit, '
        'focus ${focusUs.toStringAsFixed(1)} us/focus '
        '(5 cards x 10 KB seeds, 10 KB canonical) [sink ${sink % 2}]',
      );
    });

    test('accessors', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController c = CanvasController(prefs: prefs);
      for (final String id in _openIds) {
        c.openTool(UtilityCatalog.byId(id));
      }
      c.linkCards(1, 2, type: ContentType.text);
      for (int i = 0; i < 10; i++) {
        c.saveLayout('layout $i');
      }
      await Future<void>.delayed(Duration.zero);
      int sink = 0;
      final double byZ = _minOf(15, () {
        for (int i = 0; i < 10000; i++) {
          sink += c.cardsByZ.length;
        }
      }, reps: 10000);
      final double cards = _minOf(15, () {
        for (int i = 0; i < 10000; i++) {
          sink += c.cards.length;
        }
      }, reps: 10000);
      final double groups = _minOf(15, () {
        for (int i = 0; i < 10000; i++) {
          sink += c.groups.length;
        }
      }, reps: 10000);
      final double groupFor = _minOf(15, () {
        for (int i = 0; i < 10000; i++) {
          sink += c.groupForCard(1 + i % 5)?.id ?? 0;
        }
      }, reps: 10000);
      final double channelFor = _minOf(15, () {
        for (int i = 0; i < 10000; i++) {
          sink += c.channelForCard(1 + i % 5) == null ? 0 : 1;
        }
      }, reps: 10000);
      final double names = _minOf(15, () {
        for (int i = 0; i < 100; i++) {
          sink += c.layoutNames.length;
        }
      }, reps: 100);
      c.dispose();
      // ignore: avoid_print
      print(
        '[accessors] cardsByZ ${byZ.toStringAsFixed(3)} us, '
        'cards ${cards.toStringAsFixed(3)} us, '
        'groups ${groups.toStringAsFixed(3)} us, '
        'groupForCard ${groupFor.toStringAsFixed(3)} us, '
        'channelForCard ${channelFor.toStringAsFixed(3)} us, '
        'layoutNames ${names.toStringAsFixed(1)} us (10 layouts) '
        '[sink ${sink % 2}]',
      );
    });
  });
}
