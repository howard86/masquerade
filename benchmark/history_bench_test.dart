// Benchmarks for history, drafts, and scope subscriptions.
//
// Not under test/ so CI's `flutter test` skips it. Run with:
//   flutter test benchmark/history_bench_test.dart
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/screens/history_screen.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/tool_draft_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:masquerade/widgets/tool_bodies/diff_body.dart';
import 'package:masquerade/widgets/tool_bodies/generator_body.dart';
import 'package:masquerade/widgets/tool_bodies/json_body.dart';
import 'package:masquerade/widgets/tool_bodies/regex_body.dart';
import 'package:masquerade/widgets/tool_bodies/uuid_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _n = 15;

/// Ordinary, non-sensitive text of roughly [bytes] characters.
String _text(int seed, int bytes) {
  final StringBuffer b = StringBuffer();
  int i = 0;
  while (b.length < bytes) {
    b.write('lorem ipsum $seed dolor ${i++} sit amet consectetur\n');
  }
  return b.toString().substring(0, bytes);
}

/// 200 entries of 10–20 KB (input + output), half plain JSON-tool text, half
/// base64 (which forces the decode branch of the sensitivity scan).
List<HistoryEntry> _entries(int count, {int salt = 0}) {
  final DateTime now = DateTime.now();
  return <HistoryEntry>[
    for (int i = 0; i < count; i++)
      if (i.isEven)
        HistoryEntry(
          utilityId: 'json',
          input: _text(i + salt, 8000 + (i % 7) * 1000),
          output: _text(i + salt + 1, 4000),
          timestamp: now.subtract(Duration(minutes: i)),
        )
      else
        HistoryEntry(
          utilityId: 'base64',
          input: base64.encode(utf8.encode(_text(i + salt, 6000))),
          output: _text(i + salt, 6000),
          timestamp: now.subtract(Duration(minutes: i)),
        ),
  ];
}

double _minUs(void Function() body, {int n = _n}) {
  for (int i = 0; i < 3; i++) {
    body();
  }
  int best = 1 << 62;
  for (int i = 0; i < n; i++) {
    final Stopwatch sw = Stopwatch()..start();
    body();
    sw.stop();
    if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
  }
  return best.toDouble();
}

Future<double> _minUsAsync(Future<void> Function() body, {int n = _n}) async {
  for (int i = 0; i < 3; i++) {
    await body();
  }
  int best = 1 << 62;
  for (int i = 0; i < n; i++) {
    final Stopwatch sw = Stopwatch()..start();
    await body();
    sw.stop();
    if (sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
  }
  return best.toDouble();
}

void _report(String name, double us) =>
    print('BENCH $name: ${(us / 1000).toStringAsFixed(3)} ms');

Widget _host(
  HistoryController history,
  Widget child, {
  ToolDraftController? drafts,
}) {
  Widget body = child;
  if (drafts != null) body = ToolDraftScope(controller: drafts, child: body);
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: HistoryScope(controller: history, child: body),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('history add + persist, 200 x 10-20 KB entries', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController c = HistoryController(
      prefs: prefs,
      retention: const Duration(days: 36500),
    );
    for (final HistoryEntry e in _entries(200).reversed) {
      await c.add(e);
    }
    await c.flushForBench();
    int k = 0;
    final List<HistoryEntry> extra = _entries(40, salt: 9999);
    final double us = await _minUsAsync(() async {
      await c.add(extra[k++ % extra.length]);
      await c.flushForBench();
    });
    _report('history.add+persist (200 entries)', us);
    print(
      'BENCH history.persisted bytes: ${prefs.getString('mb.history.entries')!.length}',
    );
  });

  test('history add + persist, burst of 10 adds', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController c = HistoryController(
      prefs: prefs,
      retention: const Duration(days: 36500),
    );
    for (final HistoryEntry e in _entries(200).reversed) {
      await c.add(e);
    }
    await c.flushForBench();
    int k = 0;
    final List<HistoryEntry> extra = _entries(40, salt: 5555);
    final double us = await _minUsAsync(() async {
      for (int i = 0; i < 10; i++) {
        await c.add(extra[k++ % extra.length]);
      }
      await c.flushForBench();
    });
    _report('history.add x10 burst + flush', us);
  });

  test('stored bytes for 50 oversized (40 KB input) + 150 normal adds', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController c = HistoryController(
      prefs: prefs,
      retention: const Duration(days: 36500),
    );
    final List<HistoryEntry> normal = _entries(150);
    for (int i = 0; i < 200; i++) {
      await c.add(
        i % 4 == 0
            ? HistoryEntry(
                utilityId: 'json',
                input: _text(i + 777, 40000),
                output: _text(i, 40000),
                timestamp: DateTime.now(),
              )
            : normal[i - i ~/ 4 - 1],
      );
    }
    await c.flushForBench();
    print(
      'BENCH history.stored bytes mixed: ${prefs.getString('mb.history.entries')!.length} (${c.entries.length} entries)',
    );
  });

  test('HistoryEntry.protected x3 per entry (row build pattern)', () {
    final List<HistoryEntry> entries = _entries(200);
    final double us = _minUs(() {
      for (final HistoryEntry e in entries) {
        SensitiveDataPolicy.safePreview(
          e.input,
          max: 32,
          utilityId: e.utilityId,
          sensitive: e.sensitive,
        );
        SensitiveDataPolicy.safePreview(
          e.output,
          max: 32,
          utilityId: e.utilityId,
          sensitive: e.sensitive,
        );
        // ignore: unnecessary_statements
        e.protected;
      }
    });
    _report('200 rows x (2 safePreview + protected) [old row pattern]', us);
    final double cached = _minUs(() {
      for (final HistoryEntry e in entries) {
        // ignore: unnecessary_statements
        e.protected;
      }
    });
    _report('200 x entry.protected', cached);
  });

  test('Artifact.isSensitive + safePreview + sensitivity', () {
    final List<Artifact<Object?>> artifacts = <Artifact<Object?>>[
      for (int i = 0; i < 200; i++)
        Artifact<Object?>(
          kind: i.isEven ? ArtifactKind.base64 : ArtifactKind.json,
          rawValue: i.isEven
              ? base64.encode(utf8.encode(_text(i, 6000)))
              : _text(i, 10000),
          provenance: ArtifactProvenance.typed,
        ),
    ];
    final double us = _minUs(() {
      for (final Artifact<Object?> a in artifacts) {
        // ignore: unnecessary_statements
        a.isSensitive;
        // ignore: unnecessary_statements
        a.sensitivity;
        // ignore: unnecessary_statements
        a.safePreview;
      }
    });
    _report('200 artifacts x (isSensitive+sensitivity+safePreview)', us);
  });

  test('SensitiveDataPolicy single-value protects', () {
    final List<String> values = <String>[
      for (int i = 0; i < 2000; i++) 'value $i plain text',
    ];
    final double us = _minUs(() {
      for (final String v in values) {
        SensitiveDataPolicy.persistedValue(v, utilityId: 'diff');
      }
    });
    _report('2000 x persistedValue (short)', us);
    final double enc = _minUs(() {
      for (final String v in values) {
        SensitiveDataPolicy.containsSecretLikeValue(v);
      }
    });
    _report('2000 x containsSecretLikeValue (short)', enc);
  });

  test(
    'draft saves: 20 keystrokes on a 200 KB JSON draft + diff draft',
    () async {
      final ToolDraftController d = await ToolDraftController.load();
      final String big = '{"k":"${_text(1, 200000)}"}';
      await d.saveDiff(
        a: _text(2, 50000),
        b: _text(3, 50000),
        wordHighlight: true,
        ignoreWhitespace: false,
      );
      int k = 0;
      final double us = await _minUsAsync(() async {
        for (int i = 0; i < 20; i++) {
          await d.saveJson(
            input: '$big${k++}',
            source: 'auto',
            target: 'prettyJson',
          );
        }
        await d.flushForBench();
      });
      _report('20 x saveJson(200 KB) + flush', us);
    },
  );

  testWidgets('history screen: pump 200 entries + type query', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController history = HistoryController(
      prefs: prefs,
      retention: const Duration(days: 36500),
    );
    for (final HistoryEntry e in _entries(200).reversed) {
      await history.add(e);
    }
    final Stopwatch first = Stopwatch()..start();
    await tester.pumpWidget(_host(history, const HistoryBody()));
    first.stop();
    _report(
      'HistoryBody first pump (200 entries)',
      first.elapsedMicroseconds.toDouble(),
    );

    int best = 1 << 62;
    const List<String> queries = <String>['l', 'lo', 'lor', 'lore', 'lorem'];
    for (int round = 0; round < 4; round++) {
      for (final String q in queries) {
        await tester.enterText(find.byType(CupertinoSearchTextField), q);
        final Stopwatch sw = Stopwatch()..start();
        await tester.pump();
        sw.stop();
        if (round > 0 && sw.elapsedMicroseconds < best) {
          best = sw.elapsedMicroseconds;
        }
      }
    }
    _report('HistoryBody keystroke pump (min)', best.toDouble());

    int bestNoMatch = 1 << 62;
    for (int round = 0; round < 12; round++) {
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'zzq$round',
      );
      final Stopwatch sw = Stopwatch()..start();
      await tester.pump();
      sw.stop();
      if (round > 1 && sw.elapsedMicroseconds < bestNoMatch) {
        bestNoMatch = sw.elapsedMicroseconds;
      }
    }
    _report(
      'HistoryBody no-match keystroke pump (min)',
      bestNoMatch.toDouble(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await history.flushForBench();
  });

  testWidgets('tool grid card build with a 20 KB last entry', (
    WidgetTester tester,
  ) async {
    final HistoryController history = HistoryController();
    final HistoryEntry entry = _entries(2)[1];
    final UtilityDescriptor d = UtilityCatalog.byId('base64');
    int best = 1 << 62;
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(
        _host(
          history,
          Column(
            children: <Widget>[
              for (int j = 0; j < 30; j++)
                SizedBox(
                  key: ValueKey<String>('$i-$j'),
                  height: 20,
                  width: 200,
                  child: ToolGridCard(
                    descriptor: d,
                    matched: false,
                    lastEntry: entry,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ),
      );
      final Stopwatch sw = Stopwatch()..start();
      tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
      await tester.pump();
      sw.stop();
      if (i > 2 && sw.elapsedMicroseconds < best) best = sw.elapsedMicroseconds;
    }
    _report('30 grid cards rebuild (min)', best.toDouble());
  });

  testWidgets('body rebuilds after history.add', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController history = HistoryController(prefs: prefs);
    final ToolDraftController drafts = ToolDraftController(prefs: prefs);
    await tester.pumpWidget(
      _host(
        history,
        drafts: drafts,
        const SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SizedBox(height: 500, child: UuidBody()),
              SizedBox(height: 500, child: RegexBody()),
              SizedBox(height: 500, child: DiffBody()),
              SizedBox(height: 500, child: GeneratorBody()),
              SizedBox(height: 500, child: JSONBody()),
              SizedBox(height: 500, child: Base64Body()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Set<String> bodyTypes = <String>{
      'UuidBody',
      'RegexBody',
      'DiffBody',
      'GeneratorBody',
      'JSONBody',
      'Base64Body',
    };
    int bodyRebuilds = 0;
    int allRebuilds = 0;
    debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
      allRebuilds++;
      if (bodyTypes.contains(e.widget.runtimeType.toString())) bodyRebuilds++;
    };
    final Stopwatch sw = Stopwatch()..start();
    await history.add(
      HistoryEntry(
        utilityId: 'json',
        input: '{"a":1}',
        output: '{"a":1}',
        timestamp: DateTime.now(),
      ),
    );
    await tester.pump();
    sw.stop();
    debugOnRebuildDirtyWidget = null;
    print(
      'BENCH body rebuilds after history.add: $bodyRebuilds (all elements: $allRebuilds)',
    );
    _report(
      'history.add + pump with 6 bodies',
      sw.elapsedMicroseconds.toDouble(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await history.flushForBench();
    await drafts.flushForBench();
  });
}

// Baseline shim: controllers had no flush API; persistence was synchronous.
extension on HistoryController {
  Future<void> flushForBench() async {}
}

extension on ToolDraftController {
  Future<void> flushForBench() async {}
}
