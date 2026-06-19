import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_status.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  group('MqStatus semantics', () {
    testWidgets('danger pill is a live region labelled with the error text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const MqStatus(
            label: 'Invalid JSON at line 3',
            kind: MqStatusKind.danger,
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(MqStatus));
      expect(node.label, 'Invalid JSON at line 3');
      expect(node.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    testWidgets('warning pill also announces as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(const MqStatus(label: 'Deprecated', kind: MqStatusKind.warning)),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(MqStatus));
      expect(node.label, 'Deprecated');
      expect(node.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    testWidgets('success pill carries a label but is not a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(const MqStatus(label: 'Copied', kind: MqStatusKind.success)),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(MqStatus));
      expect(node.label, 'Copied');
      expect(node.flagsCollection.isLiveRegion, isFalse);

      handle.dispose();
    });
  });
}
