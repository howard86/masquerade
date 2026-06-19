import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
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

  group('MqStatus layout', () {
    testWidgets('a very long label wraps instead of overflowing in a '
        'constrained width', (WidgetTester tester) async {
      final String longLabel = 'Invalid input: ${'x' * 300}';

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 150,
            child: MqStatus(label: longLabel, kind: MqStatusKind.danger),
          ),
        ),
      );

      // No RenderFlex/overflow exception was thrown during layout.
      expect(tester.takeException(), isNull);

      // The label soft-wraps within the constraint rather than running off the
      // edge: it stays inside 150px and grows tall (many lines), not wide.
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(Flexible),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.softWrap, isTrue);
      expect(paragraph.size.width, lessThanOrEqualTo(150));
      final double singleLineHeight = paragraph.getMinIntrinsicHeight(
        double.infinity,
      );
      expect(
        paragraph.size.height,
        greaterThan(singleLineHeight),
        reason: 'long label should wrap onto multiple lines',
      );
    });

    testWidgets('a short label keeps the pill hugging its content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const MqStatus(label: 'OK', kind: MqStatusKind.success)),
      );

      expect(tester.takeException(), isNull);

      // The pill (Row + padded Container) stays narrow — far from the screen
      // width — proving mainAxisSize.min still hugs short content.
      final Size pillSize = tester.getSize(find.byType(MqStatus));
      expect(pillSize.width, lessThan(120));
    });
  });
}
