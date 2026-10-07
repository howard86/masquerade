import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:masquerade/widgets/tool_bodies/regex_body.dart';
import 'package:masquerade/widgets/tool_bodies/uuid_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a history write does not rebuild mounted tool bodies', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final HistoryController history = HistoryController(
      prefs: await SharedPreferences.getInstance(),
    );
    int historyReaders = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: history,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 600, child: UuidBody()),
                  const SizedBox(height: 600, child: RegexBody()),
                  const SizedBox(height: 600, child: Base64Body()),
                  Builder(
                    builder: (BuildContext context) {
                      HistoryScope.of(context);
                      historyReaders++;
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final List<String> rebuilt = <String>[];
    debugOnRebuildDirtyWidget = (Element e, bool _) =>
        rebuilt.add(e.widget.runtimeType.toString());
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    final int readersBefore = historyReaders;
    await history.add(
      HistoryEntry(
        utilityId: 'json',
        input: '{"a":1}',
        output: '{"a":1}',
        timestamp: DateTime.now(),
      ),
    );
    await tester.pump();
    debugOnRebuildDirtyWidget = null;

    expect(
      rebuilt.where(
        (String t) =>
            <String>{'UuidBody', 'RegexBody', 'Base64Body'}.contains(t),
      ),
      isEmpty,
    );
    // Widgets that render history still subscribe through `of`.
    expect(historyReaders, readersBefore + 1);
  });

  testWidgets('read returns the scoped controller', (
    WidgetTester tester,
  ) async {
    final HistoryController history = HistoryController();
    late HistoryController read;
    await tester.pumpWidget(
      HistoryScope(
        controller: history,
        child: Builder(
          builder: (BuildContext context) {
            read = HistoryScope.read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(read, same(history));
  });
}
