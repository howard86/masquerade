// Diff body render benchmark. Not under test/, so CI's `flutter test` skips
// it; run with `flutter test benchmark/diff_body_bench_test.dart`.
//
// Pumps DiffBody with two 5000-line inputs (every 10th line changed, so the
// hunks cover nearly every line) and reports, min of N (debug-mode
// flutter_test, no rasterizer):
//  * convert: the debounce pump that diffs, builds and lays out the view,
//  * rebuild: a plain rebuild of the body with the same result,
//  * elements: rows mounted for the diff view.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/tool_bodies/diff_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _lines = 5000;
const int _runs = 5;

String _text({required bool changed}) => <String>[
  for (int i = 0; i < _lines; i++)
    changed && i % 10 == 0
        ? 'line $i changed value = ${i * 7} // edited'
        : 'line $i value = ${i * 7} // some trailing context text',
].join('\n');

Future<void> _pump(WidgetTester tester, String a) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1400));
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
            child: SingleChildScrollView(child: DiffBody(initialInput: a)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(
    // ignore: invalid_use_of_visible_for_testing_member
    () => SharedPreferences.setMockInitialValues(<String, Object>{}),
  );

  testWidgets('DiffBody 2×5000 lines', (WidgetTester tester) async {
    final String a = _text(changed: false);
    final String b = _text(changed: true);
    int convertMin = 1 << 62;
    int rebuildMin = 1 << 62;
    int rows = 0;
    for (int run = 0; run < _runs; run++) {
      await _pump(tester, a);
      await tester.enterText(find.byType(EditableText).last, b);
      final Stopwatch convert = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 300));
      convert.stop();
      if (convert.elapsedMicroseconds < convertMin) {
        convertMin = convert.elapsedMicroseconds;
      }
      final Stopwatch rebuild = Stopwatch()..start();
      tester.element(find.byType(DiffBody)).markNeedsBuild();
      tester.renderObject(find.byType(DiffBody)).markNeedsLayout();
      await tester.pump();
      rebuild.stop();
      if (rebuild.elapsedMicroseconds < rebuildMin) {
        rebuildMin = rebuild.elapsedMicroseconds;
      }
      rows = find
          .byWidgetPredicate(
            (Widget w) => w.runtimeType.toString() == '_DiffRow',
          )
          .evaluate()
          .length;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }
    // ignore: avoid_print
    print(
      'diff_body_bench convert_ms=${(convertMin / 1000).toStringAsFixed(1)} '
      'rebuild_ms=${(rebuildMin / 1000).toStringAsFixed(1)} rows=$rows',
    );
    await tester.binding.setSurfaceSize(null);
  });
}
