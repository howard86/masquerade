import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/theme/mq_typography.dart';
import 'package:masquerade/widgets/mq/page_masthead.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: child),
  ),
);

void main() {
  group('PageMasthead', () {
    testWidgets('renders title in display tier', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const PageMasthead(title: 'Masquerade')));
      expect(find.text('Masquerade'), findsOneWidget);
      final Text title = tester.widget<Text>(find.text('Masquerade'));
      expect(title.style?.fontSize, MqTextStyles.display.fontSize);
      expect(title.style?.fontFamily, MqTextStyles.serifFamily);
    });

    testWidgets('renders tagline only when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const PageMasthead(title: 'X')));
      expect(find.text('utility toolbox'), findsNothing);

      await tester.pumpWidget(
        _host(const PageMasthead(title: 'X', tagline: 'utility toolbox')),
      );
      expect(find.text('utility toolbox'), findsOneWidget);
    });

    testWidgets('rule defaults to true and can be turned off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const PageMasthead(title: 'X')));
      // Default: a Container with 0.5px height carries the rule.
      final Iterable<Container> containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final bool hasRule = containers.any(
        (Container c) => c.constraints?.maxHeight == 0.5,
      );
      expect(hasRule, isTrue);

      await tester.pumpWidget(
        _host(const PageMasthead(title: 'X', rule: false)),
      );
      final Iterable<Container> containers2 = tester.widgetList<Container>(
        find.byType(Container),
      );
      final bool hasRule2 = containers2.any(
        (Container c) => c.constraints?.maxHeight == 0.5,
      );
      expect(hasRule2, isFalse);
    });
  });
}
