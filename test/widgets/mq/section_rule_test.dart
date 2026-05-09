import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/section_rule.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: child),
  ),
);

void main() {
  group('SectionRule', () {
    testWidgets('renders a hairline with no label by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const SectionRule()));
      // No label-floating Stack inside SectionRule itself.
      expect(
        find.descendant(
          of: find.byType(SectionRule),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
      // Hairline container at 0.5 height present.
      final Iterable<Container> containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(SectionRule),
          matching: find.byType(Container),
        ),
      );
      expect(
        containers.any((Container c) => c.constraints?.maxHeight == 0.5),
        isTrue,
      );
    });

    testWidgets('label is rendered uppercased over the rule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const SectionRule(label: 'recents')));
      expect(find.text('RECENTS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SectionRule),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });
  });
}
