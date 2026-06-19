import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_empty_hint.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  group('MqEmptyHint semantics', () {
    testWidgets('exposes the hint label to the accessibility tree', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(const MqEmptyHint(label: 'Nothing to show yet')),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(MqEmptyHint));
      expect(node.label, 'Nothing to show yet');

      handle.dispose();
    });

    testWidgets('combines label and detail into one semantic line', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const MqEmptyHint(
            label: 'No results',
            detail: 'Try a different query',
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(MqEmptyHint));
      expect(node.label, 'No results. Try a different query');

      handle.dispose();
    });
  });
}
