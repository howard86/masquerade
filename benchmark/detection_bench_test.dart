// Detection pipeline benchmark. Lives outside test/ so CI's `flutter test`
// skips it; run with `flutter test benchmark/detection_bench_test.dart`.
//
// Reports min-of-N wall time for `UtilityCatalog.detectArtifacts` over
// deterministic 1 KB / 100 KB / 1 MB fixtures, a per-detector breakdown on the
// 100 KB fixtures, and widget benches that time rebuilds which do not change
// the detected text (footer parent rebuilds, Home caret moves).
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/json_parser.dart';
import 'package:masquerade/utils/number_base_parser.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<int> _sizes = <int>[1024, 100 * 1024, 1024 * 1024];

String _label(int size) =>
    size >= 1024 * 1024 ? '${size ~/ (1024 * 1024)} MB' : '${size ~/ 1024} KB';

String _fill(int size, String Function(int i) line) {
  final StringBuffer b = StringBuffer();
  for (int i = 0; b.length < size; i++) {
    b.writeln(line(i));
  }
  return b.toString().substring(0, size).trimRight();
}

String logFixture(int size) => _fill(
  size,
  (int i) =>
      '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}T10:${(i % 60).toString().padLeft(2, '0')}:00Z '
      '${const <String>['INFO', 'WARN', 'ERROR', 'DEBUG'][i % 4]} '
      'service.worker[$i] handled request id=$i path=/api/v1/items/$i '
      'status=${200 + i % 3} latency_ms=${i % 997}',
);

String jsonFixture(int size) {
  final List<Map<String, Object?>> items = <Map<String, Object?>>[];
  int length = 2;
  for (int i = 0; length < size; i++) {
    final Map<String, Object?> item = <String, Object?>{
      'id': i,
      'name': 'item-$i',
      'active': i.isEven,
      'tags': <String>['alpha', 'beta$i'],
      'nested': <String, Object?>{'score': i * 1.5, 'note': 'value $i'},
    };
    items.add(item);
    length += const JsonEncoder.withIndent('  ').convert(item).length + 4;
  }
  return const JsonEncoder.withIndent('  ').convert(items);
}

String csvFixture(int size) {
  final StringBuffer b = StringBuffer('id,name,qty,price,region\n');
  for (int i = 0; b.length < size; i++) {
    b.writeln('$i,item$i,${i % 50},${(i % 1000) / 10},r${i % 7}');
  }
  return b.toString().trimRight();
}

String base64Fixture(int size) {
  // Printable ASCII payload so the base64 detector takes its full path.
  final int raw = size * 3 ~/ 4;
  final StringBuffer b = StringBuffer();
  for (int i = 0; b.length < raw; i++) {
    b.write('line $i of the printable payload; ');
  }
  return base64Encode(utf8.encode(b.toString().substring(0, raw - raw % 3)));
}

final Map<String, String Function(int)> fixtures =
    <String, String Function(int)>{
      'log': logFixture,
      'json': jsonFixture,
      'csv': csvFixture,
      'base64': base64Fixture,
    };

double _minMicros(void Function() body, {int runs = 12, int warmup = 2}) {
  for (int i = 0; i < warmup; i++) {
    body();
  }
  int best = 1 << 62;
  for (int i = 0; i < runs; i++) {
    final Stopwatch sw = Stopwatch()..start();
    body();
    sw.stop();
    if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
  }
  return best.toDouble();
}

String _ms(double micros) => '${(micros / 1000).toStringAsFixed(3)} ms';

Widget _footerHarness(Widget child) => CupertinoApp(
  builder: (BuildContext _, Widget? root) => MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: DetectionPreferenceScope(
      controller: DetectionPreferenceController(),
      child: HistoryScope(
        controller: HistoryController(),
        child: root ?? const SizedBox.shrink(),
      ),
    ),
  ),
  home: CupertinoPageScaffold(child: SingleChildScrollView(child: child)),
);

void main() {
  test('detectArtifacts sweep', () {
    print('== detectArtifacts (min of 12) ==');
    for (final MapEntry<String, String Function(int)> f in fixtures.entries) {
      for (final int size in _sizes) {
        final String input = f.value(size);
        final double us = _minMicros(
          () => UtilityCatalog.detectArtifacts(input),
          runs: size >= 1024 * 1024 ? 10 : 12,
        );
        final String kinds = UtilityCatalog.detectArtifacts(
          input,
        ).map((DetectionMatch<Object?> m) => m.primaryToolId).join(',');
        print(
          '${f.key.padRight(7)} ${_label(size).padLeft(6)}  ${_ms(us)}  [$kinds]',
        );
      }
    }
  });

  test('per-detector breakdown (100 KB)', () {
    print('== per-detector, 100 KB (min of 10) ==');
    for (final MapEntry<String, String Function(int)> f in fixtures.entries) {
      final String input = f.value(100 * 1024);
      final List<String> rows = <String>[];
      for (final UtilityDescriptor tool in UtilityCatalog.all) {
        final ArtifactDetector? detect = tool.detectArtifact;
        if (detect == null) continue;
        final double us = _minMicros(
          () => detect(input, ArtifactProvenance.typed),
          runs: 10,
        );
        if (us >= 50) rows.add('  ${tool.id.padRight(30)} ${_ms(us)}');
      }
      print('${f.key}:');
      rows.forEach(print);
    }
  });

  test('NumberBaseParser on non-numeric text', () {
    for (final int size in _sizes) {
      final String input = logFixture(size);
      print(
        'number base parse(log) ${_label(size).padLeft(6)}  '
        '${_ms(_minMicros(() => NumberBaseParser.parse(input)))}',
      );
    }
  });

  test('JSON parser: invalid input and tree view', () {
    print('== JSON parser (min of 12) ==');
    for (final int size in _sizes) {
      // Truncated mid-document: every keystroke while typing looks like this.
      final String json = jsonFixture(size);
      final String invalid = json.substring(0, json.length ~/ 2);
      final double parseUs = _minMicros(() => JSONParser.parse(invalid));
      final double noFixUs = _minMicros(
        () => JSONParser.parse(invalid, suggestFix: false),
      );
      final double detectUs = _minMicros(
        () => UtilityCatalog.detectArtifacts(invalid),
        runs: 10,
      );
      final Object? value = (JSONParser.parse(json) as JSONOk).value.value;
      final double treeUs = _minMicros(() => JSONParser.tree(value));
      print(
        '${_label(size).padLeft(6)}  parse(invalid) ${_ms(parseUs)}  '
        'parse(invalid, suggestFix: false) ${_ms(noFixUs)}  '
        'detect(invalid) ${_ms(detectUs)}  tree ${_ms(treeUs)}',
      );
    }
    // Deep nesting: 400 levels x 20 leaves, where per-level joins copy the
    // whole subtree once per ancestor.
    Object? deep = <String, Object?>{'leaf': 0};
    for (int d = 0; d < 400; d++) {
      deep = <String, Object?>{
        for (int k = 0; k < 20; k++) 'k$k': 'value $d.$k',
        'child': deep,
      };
    }
    final Object? deepValue = deep;
    print('deep tree  ${_ms(_minMicros(() => JSONParser.tree(deepValue)))}');
  });

  test('WorkSessionController: addNext and updateSettings, 100 KB', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String json = jsonFixture(100 * 1024);
    final UtilityDescriptor target = UtilityCatalog.compatibleNextSteps(
      'json',
      json,
    ).first;
    int best = 1 << 62;
    for (int i = 0; i < 12; i++) {
      final WorkSessionController c = WorkSessionController(prefs: prefs);
      c.start(
        UtilityCatalog.byId('json'),
        Artifact<Object?>(
          kind: ArtifactKind.json,
          rawValue: '{"a":1}',
          provenance: ArtifactProvenance.typed,
        ),
      );
      final Stopwatch sw = Stopwatch()..start();
      c.addNext(0, target, json);
      sw.stop();
      if (i >= 2 && sw.elapsedMicroseconds < best) {
        best = sw.elapsedMicroseconds;
      }
      await c.flush();
    }
    print('addNext(100 KB JSON -> ${target.id}): ${_ms(best.toDouble())}');

    final WorkSessionController c = WorkSessionController(prefs: prefs);
    c.start(
      UtilityCatalog.byId('json'),
      Artifact<Object?>(
        kind: ArtifactKind.json,
        rawValue: json,
        provenance: ArtifactProvenance.typed,
      ),
    );
    best = 1 << 62;
    for (int i = 0; i < 22; i++) {
      final Stopwatch sw = Stopwatch()..start();
      c.updateSettings(0, c.session!, <String, Object?>{
        'target': i.isEven ? 'tree' : 'pretty',
        'indent': i,
      });
      sw.stop();
      if (i >= 2 && sw.elapsedMicroseconds < best) {
        best = sw.elapsedMicroseconds;
      }
    }
    await c.flush();
    print('updateSettings(100 KB input step): ${_ms(best.toDouble())}');
  });

  testWidgets('OpenInFooter: 20 parent rebuilds, same 100 KB JSON output', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final String output = jsonFixture(100 * 1024);
    late StateSetter rebuild;
    await tester.pumpWidget(
      _footerHarness(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return OpenInFooter(
              output: output,
              excludeUtilityId: 'csv',
              onSwitchTool: (_, _) {},
            );
          },
        ),
      ),
    );
    int best = 1 << 62;
    int total = 0;
    for (int i = 0; i < 20; i++) {
      rebuild(() {});
      final Stopwatch sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      total += sw.elapsedMicroseconds;
      if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
    }
    print(
      'footer rebuild: min ${_ms(best.toDouble())}, total 20 = ${_ms(total.toDouble())}',
    );
  });

  testWidgets('Home: 20 caret moves over 100 KB log input', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const Size phone = Size(393, 852);
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: phone),
        child: MyApp(skipSplash: true),
      ),
    );
    await tester.pumpAndSettle();
    final String input = logFixture(100 * 1024);
    await tester.enterText(find.byType(CupertinoTextField).first, input);
    await tester.pump();
    final TextEditingController controller = tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField).first)
        .controller!;
    int best = 1 << 62;
    int total = 0;
    for (int i = 0; i < 20; i++) {
      controller.selection = TextSelection.collapsed(offset: 10 + i);
      final Stopwatch sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      total += sw.elapsedMicroseconds;
      if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
    }
    print(
      'home caret move: min ${_ms(best.toDouble())}, total 20 = ${_ms(total.toDouble())}',
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
