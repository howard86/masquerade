// Parser & parser-body microbenchmarks. Not under test/, so CI skips it.
// Run: flutter test benchmark/parsers_bench_test.dart
// Web: flutter test --platform chrome benchmark/parsers_bench_test.dart
//
// Every case prints `BENCH <name>: min <µs> µs` (min of N after warm-up).
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/bps_parser.dart';
import 'package:masquerade/utils/bytes_parser.dart';
import 'package:masquerade/utils/color_parser.dart';
import 'package:masquerade/utils/csv_parser.dart';
import 'package:masquerade/utils/diff_parser.dart';
import 'package:masquerade/utils/environment_config_inspector.dart';
import 'package:masquerade/utils/http_request_inspector.dart';
import 'package:masquerade/utils/json_parser.dart';
import 'package:masquerade/utils/log_stack_inspector.dart';
import 'package:masquerade/utils/markdown_parser.dart';
import 'package:masquerade/utils/unicode_string_inspector.dart';
import 'package:masquerade/utils/utf8_length.dart';
import 'package:masquerade/utils/x509_inspector.dart';
import 'package:masquerade/widgets/mq/md_renderer.dart';
import 'package:masquerade/widgets/tool_bodies/csv_body.dart';
import 'package:masquerade/widgets/tool_bodies/diff_body.dart';
import 'package:masquerade/widgets/tool_bodies/environment_config_inspector_body.dart';
import 'package:masquerade/widgets/tool_bodies/log_stack_inspector_body.dart';
import 'package:masquerade/widgets/mq/mq_chip.dart';

const String _leafPem = '''
-----BEGIN CERTIFICATE-----
MIIDhzCCAm+gAwIBAgIJAPGJJdILJ9MhMA0GCSqGSIb3DQEBCwUAMEExCzAJBgNV
BAYTAlRXMRMwEQYDVQQKDApNYXNxdWVyYWRlMR0wGwYDVQQDDBRNYXNxdWVyYWRl
LVRlc3QtUm9vdDAeFw0yNjA3MTgwMDU3MjJaFw0yNzA3MTgwMDU3MjJaMD0xCzAJ
BgNVBAYTAlRXMRMwEQYDVQQKDApNYXNxdWVyYWRlMRkwFwYDVQQDDBBhcGkuZXhh
bXBsZS50ZXN0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyZH1IeZ/
a25TI0Kc9aSzNQFIgJ0ckXPvZxC7EqsXov9AyFctQSmNGeCScN42U9nHk6MshcS5
9MgzlCgbB0gvWitbNItVHQg723GXu1TAXK40/nICLgmSV7F71ZZxliXPZfjKAvI1
T0l+FxWncHREfuojhFz9rsEZgfqEA714Ptio7ClFsOVQEaRCBu6mD3Spuz2vi8VM
Ck3boxlDDjGp0LHIvfJVCISAq4DFqAjxOIJpp3tru4jk77WjvhSn9Y8vABrIXM/G
KUUtivzqxKsLiHk8C7dee0oXtLFmW24eTjRPW2U0or31ahX/xn/p3IBb5m7kWC+p
YmEQ7zaC3mvOMwIDAQABo4GFMIGCMGIGA1UdEQRbMFmCEGFwaS5leGFtcGxlLnRl
c3SCEHd3dy5leGFtcGxlLnRlc3SHBMAAAgqBEG9wc0BleGFtcGxlLnRlc3SGG2h0
dHBzOi8vZXhhbXBsZS50ZXN0L3N0YXR1czAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB
/wQEAwIFoDANBgkqhkiG9w0BAQsFAAOCAQEAKlxkXDKoJFppIXhY+ATl9Fl4sy+r
Hh22toy60oYeqWfyNInvM7evjepyelf/Y8IaABEd8Q48yMLPVHlpNJg4Fm5SIx9p
5arE+1gE5ZU+QsuIfPDd+4uGHu3nY0Wzoiwy2FaJsJierFiFVBVrSHpePmfXHsp/
jVbXbGj1q+qaGQjvyWIE7XABkM99jJCb7Y6v9LP1BoOA2OQxBm7/jagoKqjwJv1l
c/usQzIh9SjVgVVER94yPMOPIaE9L44gbbzsXLZOpu7NGOxEApXZhy5sxw9v6ahL
RjVySBib6OC2aoUiNtr3LKgPncp3yNQ6YxMpI92JsbAhHW64Bmqcug/SQg==
-----END CERTIFICATE-----
''';

double bench(String name, void Function() body, {int n = 15, int warmup = 3}) {
  for (int i = 0; i < warmup; i++) {
    body();
  }
  double best = double.infinity;
  final Stopwatch sw = Stopwatch();
  for (int i = 0; i < n; i++) {
    sw
      ..reset()
      ..start();
    body();
    sw.stop();
    final double us = sw.elapsedMicroseconds.toDouble();
    if (us < best) best = us;
  }
  // ignore: avoid_print
  print('BENCH $name: min ${best.toStringAsFixed(1)} µs');
  return best;
}

Future<double> benchAsync(
  String name,
  Future<void> Function() body, {
  int n = 10,
  int warmup = 2,
}) async {
  for (int i = 0; i < warmup; i++) {
    await body();
  }
  double best = double.infinity;
  final Stopwatch sw = Stopwatch();
  for (int i = 0; i < n; i++) {
    sw
      ..reset()
      ..start();
    await body();
    sw.stop();
    final double us = sw.elapsedMicroseconds.toDouble();
    if (us < best) best = us;
  }
  // ignore: avoid_print
  print('BENCH $name: min ${best.toStringAsFixed(1)} µs');
  return best;
}

// ─── Fixtures ────────────────────────────────────────────────────────────
final String envPlain = <String>[
  for (int i = 0; i < 9999; i++) 'KEY_$i=value_$i',
].join('\n');
final String envQuoted =
    'A="start\n${List<String>.generate(9990, (int i) => 'line $i').join('\n')}\nend"\nB=1';
final String envContinuation =
    'A=start\\\n${List<String>.generate(9990, (int i) => 'part$i\\').join('\n')}\nend';

String _httpFetch() {
  final String pad = ' ' * 60;
  final StringBuffer b = StringBuffer(
    'fetch($pad"https://example.com/api"$pad,',
  );
  b.write('$pad{${pad}method$pad:$pad"POST"$pad,${pad}headers$pad:$pad{');
  for (int i = 0; i < 90; i++) {
    b.write('$pad"X-H$i"$pad:$pad"value-$i"$pad,');
  }
  b.write('$pad"Content-Type"$pad:$pad"application/json"$pad}$pad,');
  b.write('${pad}body$pad:${pad}JSON.stringify($pad{');
  for (int i = 0; i < 90; i++) {
    b.write('${pad}field_$i$pad:$pad${i * 7}$pad,');
  }
  b.write('${pad}last$pad:$pad"x"$pad}$pad)$pad}$pad)');
  return b.toString();
}

final String httpFetch = _httpFetch();
const String httpCurl =
    "curl -X POST 'https://example.com/api/v1/items?page=2&limit=10' "
    "-H 'Content-Type: application/json' -H 'Accept: application/json' "
    "-d '{\"name\":\"widget\",\"count\":3}'";

String _log() {
  final StringBuffer b = StringBuffer();
  int line = 0;
  while (line < 9990) {
    final int i = line;
    if (i % 50 == 10) {
      b.writeln(
        '2024-01-01T00:00:${(i % 60).toString().padLeft(2, '0')}Z ERROR boom $i',
      );
      b.writeln('java.lang.IllegalStateException: bad $i');
      b.writeln('    at com.example.Foo.bar(Foo.java:$i)');
      b.writeln('    at com.example.Main.main(Main.java:1)');
      line += 4;
    } else if (i % 7 == 0) {
      b.writeln('{"level":"info","ts":"2024-01-01T00:00:00Z","msg":"ok $i"}');
      line++;
    } else {
      b.writeln(
        '2024-01-01T00:00:${(i % 60).toString().padLeft(2, '0')}Z INFO req $i path=/a/$i ok',
      );
      line++;
    }
  }
  return b.toString().trimRight();
}

final String logText = _log();

String _csv() {
  final StringBuffer b = StringBuffer(
    'id,name,city,score,active,notes,code,ts\n',
  );
  for (int i = 0; i < 9000; i++) {
    b.writeln(
      '$i,name_$i,"City, $i",${i * 3}.5,${i.isEven},note number $i,C$i,2024-01-$i',
    );
  }
  return b.toString();
}

final String csvText = _csv();
final String nonCsv = '$logText\n$logText'.substring(
  0,
  min(1000000, logText.length * 2),
);
final String jsonRows = jsonEncode(<Map<String, Object?>>[
  for (int i = 0; i < 5000; i++)
    <String, Object?>{
      'id': i,
      'name': 'name_$i',
      'city': 'City, $i',
      'score': i * 1.5,
      'active': i.isEven,
      'note': 'note "$i"',
    },
]);

final String unicodeAscii = List<String>.filled(25000, 'hello wrld').join();
final String unicodeMixed = List<String>.filled(
  12000,
  'héllo wörld 😀 ',
).join();

String _diffSide(bool changed) => <String>[
  for (int i = 0; i < 5000; i++)
    changed && i % 5 == 0 ? 'changed line $i alpha' : 'line $i some text',
].join('\n');
final String diffA = _diffSide(false);
final String diffB = _diffSide(true);
final String wordA = List<String>.generate(10000, (int i) => 'w$i').join(' ');
final String wordB = List<String>.generate(
  10000,
  (int i) => i % 10 == 0 ? 'x$i' : 'w$i',
).join(' ');

String _markdown() {
  final StringBuffer b = StringBuffer();
  int i = 0;
  while (b.length < 250 * 1024) {
    b
      ..writeln('## Heading $i')
      ..writeln()
      ..writeln(
        'Paragraph $i with **bold** and _em_ and `code` and a [link](https://example.com/$i). '
        '${'lorem ipsum dolor sit amet ' * 40}',
      )
      ..writeln()
      ..writeln('- item a $i')
      ..writeln('- item b $i')
      ..writeln()
      ..writeln('```dart')
      ..writeln('void main() { print($i); }' * 4)
      ..writeln('```')
      ..writeln();
    i++;
  }
  return b.toString().substring(0, 250 * 1024);
}

final String markdownText = _markdown();
final Uint8List bytesMb = Uint8List.fromList(
  List<int>.generate(1 << 20, (int i) => (i * 31) & 0xff),
);
final String asciiMb = 'a' * (1 << 20);
final String bmpMb = 'é' * (1 << 19);

Widget _host(Widget body, {double width = 480}) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: HistoryScope(
      controller: HistoryController(),
      child: CupertinoPageScaffold(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: body),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('1 env', () {
    test('parse unclosed quote 10k lines', () {
      expect(
        EnvironmentConfigInspector.parse(
          envQuoted,
          format: ConfigFormat.environment,
        ).entries.length,
        2,
      );
      bench(
        'env.quoted10k',
        () => EnvironmentConfigInspector.parse(
          envQuoted,
          format: ConfigFormat.environment,
        ),
        n: 5,
        warmup: 1,
      );
    });
    test('parse backslash continuation 10k lines', () {
      expect(
        EnvironmentConfigInspector.parse(
          envContinuation,
          format: ConfigFormat.environment,
        ).entries.length,
        1,
      );
      bench(
        'env.continuation10k',
        () => EnvironmentConfigInspector.parse(
          envContinuation,
          format: ConfigFormat.environment,
        ),
        n: 5,
        warmup: 1,
      );
    });
    test('parse plain 10k lines', () {
      bench('env.plain10k', () => EnvironmentConfigInspector.parse(envPlain));
    });
    test('detect 10k lines', () {
      bench('env.detect10k', () => EnvironmentConfigInspector.detect(envPlain));
    });
    testWidgets('body: edit A with 10k-line B filled', (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(1024, 1400));
      await t.pumpWidget(
        _host(EnvironmentConfigInspectorBody(initialInput: envPlain)),
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byType(EditableText).last, envPlain);
      await t.pump(const Duration(milliseconds: 300));
      int k = 0;
      await benchAsync(
        'env.body.editA',
        () async {
          await t.enterText(
            find.byType(EditableText).first,
            '$envPlain\nZ=${k++}',
          );
          await t.pump(const Duration(milliseconds: 300));
        },
        n: 5,
        warmup: 1,
      );
      await t.binding.setSurfaceSize(null);
    });
  });

  group('2 http', () {
    test('fetch whitespace-heavy 64 KB', () {
      expect(httpFetch.length, lessThan(65536));
      HttpRequestInspector.parse(httpFetch);
      bench('http.fetch', () => HttpRequestInspector.parse(httpFetch), n: 20);
    });
    test('curl x1000', () {
      bench('http.curl1000', () {
        for (int i = 0; i < 1000; i++) {
          HttpRequestInspector.parse(httpCurl);
        }
      });
    });
  });

  group('3 log', () {
    test('parse 10k lines', () {
      final LogInspection r = LogStackInspector.parse(logText);
      expect(r.events, isNotEmpty);
      bench('log.parse10k', () => LogStackInspector.parse(logText), n: 10);
    });
    test('filter+export', () {
      final LogInspection r = LogStackInspector.parse(logText);
      bench('log.filterExport', () {
        final List<LogEvent> e = r.filter(query: 'req');
        r.export(e);
      });
    });
    testWidgets('body rebuild', (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(1024, 1400));
      await t.pumpWidget(_host(LogStackInspectorBody(initialInput: logText)));
      await t.pump(const Duration(milliseconds: 300));
      final StatefulElement el = t.element(find.byType(LogStackInspectorBody));
      await benchAsync('log.body.rebuild', () async {
        el.markNeedsBuild();
        await t.pump();
      });
      await t.binding.setSurfaceSize(null);
    });
  });

  group('4 csv', () {
    test('parse 1 MB auto', () {
      expect(CsvParser.parse(csvText), isA<CsvOk>());
      bench('csv.parse1mb', () => CsvParser.parse(csvText), n: 10);
    });
    test('parse 1 MB non-CSV auto', () {
      bench('csv.nonCsv1mb', () => CsvParser.parse(nonCsv), n: 10);
    });
    test('json→csv body flow', () {
      bench('csv.fromJsonFlow', () {
        final String out = CsvParser.fromJson(jsonRows);
        jsonDecode(jsonRows);
        CsvParser.parse(out, delimiter: ',');
      }, n: 10);
    });
    test('json→csv body flow (records, no re-parse)', () {
      bench('csv.fromJsonRecordsFlow', () {
        final ({String csv, List<List<String>> records, bool typedScalars}) c =
            CsvParser.fromJsonRecords(jsonRows);
        c.records.any((List<String> r) => r.any((String v) => v.isNotEmpty));
      }, n: 10);
    });
    testWidgets('body json→csv', (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(1024, 1400));
      await t.pumpWidget(_host(const CsvBody()));
      await t.tap(find.text('JSON → CSV'));
      await t.pump();
      int k = 0;
      await benchAsync(
        'csv.body.jsonToCsv',
        () async {
          await t.enterText(
            find.byType(EditableText).first,
            (k++).isEven ? jsonRows : '$jsonRows ',
          );
          await t.pump(const Duration(milliseconds: 250));
        },
        n: 5,
        warmup: 1,
      );
      await t.binding.setSurfaceSize(null);
    });
  });

  group('5 unicode', () {
    test('parse 250K ascii', () {
      bench(
        'unicode.ascii',
        () => UnicodeStringInspector.parse(unicodeAscii),
        n: 5,
      );
    });
    test('parse 200K mixed', () {
      bench(
        'unicode.mixed',
        () => UnicodeStringInspector.parse(unicodeMixed),
        n: 5,
      );
    });
  });

  group('6 diff', () {
    test('lineDiff 5000 lines, D=2000', () {
      expect(DiffTool.lineDiff(diffA, diffB).tooLarge, isFalse);
      bench('diff.line5000', () => DiffTool.lineDiff(diffA, diffB), n: 5);
    });
    test('wordDiff 20k tokens', () {
      bench(
        'diff.word20k',
        () => DiffTool.wordDiff(wordA, wordB),
        n: 3,
        warmup: 1,
      );
    });
    testWidgets('body toggle word highlight', (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(1024, 1400));
      await t.pumpWidget(_host(DiffBody(initialInput: diffA)));
      await t.pump();
      await t.enterText(find.byType(EditableText).last, diffB);
      await t.pump(const Duration(milliseconds: 300));
      await benchAsync('diff.body.toggleWord', () async {
        await t.tap(find.widgetWithText(MqChip, 'Word highlight'));
        await t.pump();
      }, n: 6);
      // The tap handler alone (diff/span work), before the rebuild pump.
      final Finder chip = find.widgetWithText(MqChip, 'Word highlight');
      double best = double.infinity;
      for (int i = 0; i < 8; i++) {
        final VoidCallback onTap = t.widget<MqChip>(chip).onTap!;
        final Stopwatch sw = Stopwatch()..start();
        onTap();
        sw.stop();
        if (i >= 2 && sw.elapsedMicroseconds < best) {
          best = sw.elapsedMicroseconds.toDouble();
        }
        await t.pump();
      }
      // ignore: avoid_print
      print('BENCH diff.body.toggleHandler: min ${best.toStringAsFixed(1)} µs');
      await t.binding.setSurfaceSize(null);
    });
  });

  group('7 markdown', () {
    testWidgets('renderer rebuild 256 KB', (WidgetTester t) async {
      final MarkdownParseResult r = MarkdownParser.parse(markdownText);
      if (r is MarkdownErr) fail(r.message);
      final MarkdownOk doc = r as MarkdownOk;
      await t.binding.setSurfaceSize(const Size(1024, 1400));
      late StateSetter set;
      await t.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext c, StateSetter s) {
              set = s;
              return MqMarkdownRenderer(blocks: doc.blocks);
            },
          ),
        ),
      );
      await benchAsync('md.rebuild', () async {
        set(() {});
        await t.pump();
      });
      // The renderer's own build (preview planning + child widget list).
      final StatelessElement el = t.element(find.byType(MqMarkdownRenderer));
      final MqMarkdownRenderer w = el.widget as MqMarkdownRenderer;
      bench('md.buildOnly', () => w.build(el), n: 20);
      // First build of a new parse: plans from scratch every time.
      bench(
        'md.planFresh',
        () => MqMarkdownRenderer(
          blocks: List<MarkdownBlock>.of(doc.blocks),
        ).build(el),
        n: 20,
      );
      await t.binding.setSurfaceSize(null);
    });
  });

  group('8 json', () {
    test('minify twice vs once (1 MB)', () {
      final Object? v = jsonDecode(jsonRows);
      bench('json.minifyTwice', () {
        JSONParser.minify(v);
        JSONParser.minify(v);
      });
      bench('json.minifyOnce', () => JSONParser.minify(v));
    });
  });

  group('9 bytes', () {
    test('format hex 1 MB', () {
      bench(
        'bytes.hex1mb',
        () => BytesParser.format(bytesMb, BytesFormat.hex),
        n: 10,
      );
    });
  });

  group('10 utf8', () {
    test('utf8.encode length 1 MB', () {
      bench('utf8.encodeLen.ascii', () => utf8.encode(asciiMb).length, n: 20);
      bench('utf8.encodeLen.bmp', () => utf8.encode(bmpMb).length, n: 20);
      bench('utf8.utf8Length.ascii', () => utf8Length(asciiMb), n: 20);
      bench('utf8.utf8Length.bmp', () => utf8Length(bmpMb), n: 20);
      bench(
        'utf8.exceeds.ascii1MiB',
        () => utf8LengthExceeds(asciiMb, 1 << 20),
        n: 20,
      );
      bench(
        'utf8.exceeds.bmp1MiB',
        () => utf8LengthExceeds(bmpMb, 1 << 20),
        n: 20,
      );
    });
  });

  group('11 dateformat', () {
    test('construct+format x10k', () {
      final DateTime t = DateTime.utc(2024, 1, 2, 3, 4, 5);
      bench('dateformat.inline10k', () {
        for (int i = 0; i < 10000; i++) {
          DateFormat('yyyy-MM-dd HH:mm:ss').format(t);
        }
      });
      final DateFormat f = DateFormat('yyyy-MM-dd HH:mm:ss');
      bench('dateformat.hoisted10k', () {
        for (int i = 0; i < 10000; i++) {
          f.format(t);
        }
      });
    });
  });

  group('12 regexp hoists', () {
    test('color/bps/x509/http', () {
      bench('re.color10k', () {
        for (int i = 0; i < 10000; i++) {
          MqColorParser.parse('rgb(10, 20, 30)');
          MqColorParser.parse('hsl(120, 50%, 50%)');
          MqColorParser.parse('#a1b2c3');
        }
      });
      bench('re.bps10k', () {
        for (int i = 0; i < 10000; i++) {
          BpsParser.parse('25 bps');
        }
      });
      final DateTime now = DateTime.utc(2025);
      bench('re.x509x200', () {
        for (int i = 0; i < 200; i++) {
          X509Inspector.parse(_leafPem, now: now);
        }
      });
    });
  });
}
