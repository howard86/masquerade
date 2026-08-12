import 'package:flutter/cupertino.dart';
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
    String? changed;

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
                  onChanged: (String value) => changed = value,
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

    await tester.tap(clear);
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changed, '');
    semantics.dispose();
  });
}
