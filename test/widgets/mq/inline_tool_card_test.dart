import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/inline_tool_card.dart';

void main() {
  group('InlineToolCard', () {
    final UtilityDescriptor sample = UtilityCatalog.byId('base64');

    Widget host({required bool expanded, required VoidCallback onToggle}) {
      return MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: InlineToolCard(
                descriptor: sample,
                expanded: expanded,
                onToggle: onToggle,
                bodyBuilder: (BuildContext _) => const Text('BODY'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('collapsed renders header only', (WidgetTester tester) async {
      await tester.pumpWidget(host(expanded: false, onToggle: () {}));
      expect(find.text(sample.name), findsOneWidget);
      expect(find.text('BODY'), findsNothing);
    });

    testWidgets('tapping header fires onToggle', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(host(expanded: false, onToggle: () => taps++));
      await tester.tap(find.text(sample.name));
      expect(taps, 1);
    });

    testWidgets('expanded renders body', (WidgetTester tester) async {
      await tester.pumpWidget(host(expanded: true, onToggle: () {}));
      await tester.pumpAndSettle();
      expect(find.text('BODY'), findsOneWidget);
    });

    testWidgets('chip icon color flips between collapsed and expanded', (
      WidgetTester tester,
    ) async {
      final MqColors light = MqColors.light();

      await tester.pumpWidget(host(expanded: false, onToggle: () {}));
      Icon icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(InlineToolCard),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icon.color, light.textPri);

      await tester.pumpWidget(host(expanded: true, onToggle: () {}));
      await tester.pumpAndSettle();
      icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(InlineToolCard),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icon.color, light.accent);
    });
  });
}
