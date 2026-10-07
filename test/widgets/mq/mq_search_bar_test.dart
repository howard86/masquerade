import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_search_bar.dart';

void main() {
  testWidgets('field and clear action have 44 point targets', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TextEditingController controller = TextEditingController(
      text: 'json',
    );
    addTearDown(controller.dispose);
    final List<String> changes = <String>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 320,
                child: MqSearchBar(
                  controller: controller,
                  onChanged: changes.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(MqSearchBar)).height, 44.5);
    expect(tester.getSize(find.byType(CupertinoTextField)).height, 44);
    final Finder clear = find.bySemanticsLabel('Clear search');
    expect(tester.getRect(clear).size, const Size(44, 44));
    expect(
      tester
          .getSemantics(clear)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(clear);
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes, <String>['']);

    controller.text = 'uuid';
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes, <String>['', '']);

    controller.text = 'base64';
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes, <String>['', '', '']);
    semantics.dispose();
  });
}
