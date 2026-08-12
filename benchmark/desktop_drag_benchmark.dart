import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/tool_action_bar.dart';
import 'package:masquerade/widgets/tool_bodies/seed_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _warmupFrames = 200;
const int _batchCount = 30;
const int _framesPerBatch = 20;
const int _measuredFrames = _batchCount * _framesPerBatch;

int _bodyBuilderCalls = 0;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: desktop_drag_benchmark <output.json>');
    exitCode = 64;
    return;
  }
  assert(false, 'Run with flutter run --profile.');

  final LiveTestWidgetsFlutterBinding binding =
      LiveTestWidgetsFlutterBinding.ensureInitialized()
        ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late Map<String, Object?> result;
  await benchmarkWidgets((WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      MyApp(
        desktopShellOverride: true,
        viewModeController: ViewModeController(initial: MqViewMode.desktop),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    final CanvasController canvas = tester
        .widget<DesktopMenubar>(find.byType(DesktopMenubar))
        .controller;
    final String text = List<String>.generate(
      100,
      (int i) => 'line $i: value-${i % 10}',
    ).join('\n');
    final List<(String, String?)> workload = <(String, String?)>[
      (
        'json',
        '{"items":[${List<String>.generate(200, (int i) => '$i').join(',')}]}',
      ),
      (
        'markdown',
        List<String>.generate(
          100,
          (int i) => '## Heading $i\n$text',
        ).join('\n'),
      ),
      ('log_stack_inspector', text),
      ('diff', text),
      ('list', text),
      ('base64', text),
      ('math', '(12345 * 6789) / 3'),
      ('uuid', null),
    ];
    for (final (String id, String? seed) in workload) {
      canvas.openTool(_measured(UtilityCatalog.byId(id)), seed: seed);
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    final Finder windows = find.byType(ToolCardFrame);
    if (windows.evaluate().length != workload.length) {
      throw StateError('Expected ${workload.length} windows.');
    }
    final Finder dragged = windows.last;
    final Offset start = tester.getTopLeft(dragged);
    final TestGesture gesture = await tester.startGesture(
      start + const Offset(180, 18),
    );

    for (int i = 0; i < _warmupFrames; i++) {
      await gesture.moveBy(Offset(i.isEven ? 3 : -3, 0));
      await tester.pump();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final List<FrameTiming> timings = <FrameTiming>[];
    void record(List<FrameTiming> values) => timings.addAll(values);
    _bodyBuilderCalls = 0;
    binding.addTimingsCallback(record);
    for (int i = 0; i < _measuredFrames; i++) {
      await gesture.moveBy(Offset(i.isEven ? 3 : -3, 0));
      await tester.pump();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    binding.removeTimingsCallback(record);

    final Offset end = tester.getTopLeft(dragged);
    final int measuredBodyBuilderCalls = _bodyBuilderCalls;
    await gesture.up();
    await tester.pump();

    final List<int> buildUs = timings
        .map((FrameTiming timing) => timing.buildDuration.inMicroseconds)
        .toList(growable: false);
    final List<int> rasterUs = timings
        .map((FrameTiming timing) => timing.rasterDuration.inMicroseconds)
        .toList(growable: false);
    final bool complete = timings.length == _measuredFrames;
    result = <String, Object?>{
      'schema': 1,
      'metric': 'desktop_drag_build_us',
      'lower_is_better': true,
      'cwd': Directory.current.path,
      'environment': <String, Object?>{
        'device': 'macos-arm64',
        'dart': Platform.version.split(' ').first,
        'surface': '1200x900',
        'cards': workload.length,
        'warmupFrames': _warmupFrames,
        'batchCount': _batchCount,
        'framesPerBatch': _framesPerBatch,
      },
      'complete': complete,
      'frameCount': timings.length,
      'bodyBuilderCalls': measuredBodyBuilderCalls,
      'expectedBodyBuilderCalls': 0,
      'start': <String, double>{'x': start.dx, 'y': start.dy},
      'end': <String, double>{'x': end.dx, 'y': end.dy},
      'samples': complete ? _batchMedians(buildUs) : <int>[],
      'rawBuildUs': buildUs,
      'rasterSamples': complete ? _batchMedians(rasterUs) : <int>[],
      'rawRasterUs': rasterUs,
      'missedBuildFrames': buildUs.where((int us) => us > 16667).length,
      'missedRasterFrames': rasterUs.where((int us) => us > 16667).length,
      if (complete) ...<String, Object?>{
        'buildMedianUs': _percentile(buildUs, 0.5),
        'buildP95Us': _percentile(buildUs, 0.95),
        'rasterMedianUs': _percentile(rasterUs, 0.5),
        'rasterP95Us': _percentile(rasterUs, 0.95),
      },
    };
  });

  final String encoded = const JsonEncoder.withIndent('  ').convert(result);
  if (args.single == '-') {
    stdout.writeln(encoded);
  } else {
    File(args.single).writeAsStringSync('$encoded\n');
  }
  if (result['complete'] != true ||
      result['bodyBuilderCalls'] != result['expectedBodyBuilderCalls'] ||
      result['start'].toString() != result['end'].toString()) {
    stderr.writeln(const JsonEncoder.withIndent('  ').convert(result));
    exitCode = 1;
  }
  exit(exitCode);
}

UtilityDescriptor _measured(UtilityDescriptor source) => UtilityDescriptor(
  id: source.id,
  name: source.name,
  description: source.description,
  icon: source.icon,
  tint: source.tint,
  synonyms: source.synonyms,
  categories: source.categories,
  acceptedTypes: source.acceptedTypes,
  producedTypes: source.producedTypes,
  sensitivity: source.sensitivity,
  inputSources: source.inputSources,
  liveLinkTypes: source.liveLinkTypes,
  quickActions: source.quickActions,
  batchCapable: source.batchCapable,
  historyPolicy: source.historyPolicy,
  defaultCardWidth: source.defaultCardWidth,
  detectArtifact: source.detectArtifact,
  builder:
      (
        BuildContext context, {
        String? initialInput,
        Artifact<Object?>? initialArtifact,
        SeedSource seedSource = SeedSource.none,
        OpenInToolCallback? onSwitchTool,
        ToolActionBarController? actionBar,
        LinkChannel? link,
      }) {
        _bodyBuilderCalls++;
        return source.builder(
          context,
          initialInput: initialInput,
          initialArtifact: initialArtifact,
          seedSource: seedSource,
          onSwitchTool: onSwitchTool,
          actionBar: actionBar,
          link: link,
        );
      },
);

List<int> _batchMedians(List<int> values) => <int>[
  for (int batch = 0; batch < _batchCount; batch++)
    _percentile(
      values.sublist(batch * _framesPerBatch, (batch + 1) * _framesPerBatch),
      0.5,
    ),
];

int _percentile(List<int> values, double fraction) {
  final List<int> sorted = List<int>.of(values)..sort();
  return sorted[((sorted.length - 1) * fraction).round()];
}
