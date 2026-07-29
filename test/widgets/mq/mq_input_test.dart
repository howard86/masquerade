import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  group('MqInput error semantics', () {
    testWidgets('error text is a live region labelled with the error string', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        _host(MqInput(controller: controller, error: 'Invalid JSON syntax')),
      );

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel('Invalid JSON syntax'),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    testWidgets('no error means no live region node is created', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(_host(MqInput(controller: controller)));

      expect(find.bySemanticsLabel('Invalid JSON syntax'), findsNothing);

      handle.dispose();
    });
  });
}
