import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/inline_tool_card.dart';

Widget _harness({
  required bool expanded,
  String? previewText,
  bool sensitive = false,
}) {
  final UtilityDescriptor sample = UtilityCatalog.byId('base64');
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: CupertinoPageScaffold(
        child: Center(
          child: InlineToolCard(
            descriptor: sample,
            expanded: expanded,
            onToggle: () {},
            bodyBuilder: (BuildContext _) => const Text('BODY'),
            previewText: previewText,
            previewSensitive: sensitive,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('InlineToolCard morph', () {
    testWidgets('expanded shows leading chevron and trailing close icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(expanded: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.chevron_left), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    });

    testWidgets('collapsed hides chevron and close icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(expanded: false));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.chevron_left), findsNothing);
      expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
    });

    testWidgets('preview text renders only when collapsed and non-null', (
      WidgetTester tester,
    ) async {
      // Collapsed + preview — visible.
      await tester.pumpWidget(
        _harness(expanded: false, previewText: 'last-input'),
      );
      await tester.pumpAndSettle();
      expect(find.text('last-input'), findsOneWidget);

      // Expanded + preview — hidden (banner doesn't show preview).
      await tester.pumpWidget(
        _harness(expanded: true, previewText: 'last-input'),
      );
      await tester.pumpAndSettle();
      expect(find.text('last-input'), findsNothing);

      // Collapsed + null preview — no preview.
      await tester.pumpWidget(_harness(expanded: false));
      await tester.pumpAndSettle();
      expect(find.text('last-input'), findsNothing);
    });

    testWidgets('sensitive preview is masked with bullets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          expanded: false,
          previewText: 'sensitive-payload',
          sensitive: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('sensitive-payload'), findsNothing);
      expect(find.text('••••'), findsOneWidget);
    });
  });
}
