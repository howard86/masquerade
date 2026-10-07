// Benchmarks for the sensitivity scan.
//
// Not under test/ so CI's `flutter test` skips it. Run with:
//   flutter test benchmark/sensitive_scan_bench_test.dart
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _n = 7;
const int _size = 200 * 1024;

List<Object?> _items() => <Object?>[
  for (int i = 0; i < 4000; i++)
    <String, Object?>{
      'id': i,
      'name': 'item number $i',
      'nested': <String, Object?>{
        'flag': i.isEven,
        'values': <int>[1, 2, 3],
      },
    },
];

String _sized(String Function(Object?) enc) {
  final List<Object?> all = _items();
  int count = all.length;
  String s = enc(all);
  while (s.length > _size && count > 1) {
    count = count * 3 ~/ 4;
    s = enc(all.sublist(0, count));
  }
  return s;
}

String _prose() {
  final StringBuffer b = StringBuffer();
  int i = 0;
  while (b.length < _size) {
    b.write('lorem ipsum dolor $i sit amet, consectetur adipiscing elit.\n');
    i++;
  }
  return b.toString();
}

double _minMs(bool Function() f) {
  double best = double.infinity;
  for (int i = 0; i < _n; i++) {
    final Stopwatch sw = Stopwatch()..start();
    f();
    best = sw.elapsedMicroseconds / 1000 < best
        ? sw.elapsedMicroseconds / 1000
        : best;
  }
  return best;
}

void main() {
  test('containsSensitiveArtifact on 200 KB inputs', () {
    final Map<String, String> inputs = <String, String>{
      'json 2-space': _sized(
        (Object? o) => const JsonEncoder.withIndent('  ').convert(o),
      ),
      'json 4-space': _sized(
        (Object? o) => const JsonEncoder.withIndent('    ').convert(o),
      ),
      'json minified': _sized((Object? o) => jsonEncode(o)),
      'prose': _prose(),
    };
    inputs.forEach((String name, String text) {
      expect(SensitiveDataPolicy.containsSensitiveArtifact(text), isFalse);
      final double ms = _minMs(
        () => SensitiveDataPolicy.containsSensitiveArtifact(text),
      );
      print(
        'sensitive-scan $name (${text.length} chars): '
        '${ms.toStringAsFixed(2)} ms (min of $_n)',
      );
    });
  });

  test('WorkSessionController addNext with a 64 KB step', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String big = _prose().substring(0, 64 * 1024);
    double best = double.infinity;
    for (int i = 0; i < _n; i++) {
      final WorkSessionController c = WorkSessionController(prefs: prefs);
      c.start(
        UtilityCatalog.byId('json'),
        Artifact<Object?>(
          kind: ArtifactKind.json,
          rawValue: big,
          provenance: ArtifactProvenance.typed,
        ),
      );
      final Stopwatch sw = Stopwatch()..start();
      c.addNext(0, UtilityCatalog.byId('timestamp'), big);
      best = [
        best,
        sw.elapsedMicroseconds / 1000,
      ].reduce((a, b) => a < b ? a : b);
      await c.flush();
    }
    print(
      'work-session addNext 64 KB: ${best.toStringAsFixed(2)} ms '
      '(min of $_n)',
    );
  });
}
