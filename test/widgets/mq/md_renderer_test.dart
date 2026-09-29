import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/markdown_parser.dart';
import 'package:masquerade/widgets/mq/md_renderer.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

import '../tool_bodies/_helpers.dart';

void main() {
  testWidgets('code previews cut on rune boundaries and count the rest', (
    WidgetTester tester,
  ) async {
    final String code = '😀' * 20001;
    await pumpBodyAtWidth(
      tester,
      MqMarkdownRenderer(
        blocks: <MarkdownBlock>[MarkdownCodeBlock(code, null)],
      ),
      480,
    );
    final MqMonoCell cell = tester.widget<MqMonoCell>(find.byType(MqMonoCell));
    expect(cell.value, '${'😀' * 20000}\n… 1 characters hidden');
    expect(cell.copyValue, code);
  });

  testWidgets(
    'rebuilds reuse the plan for the same blocks and replan new ones',
    (WidgetTester tester) async {
      final List<MarkdownBlock> first = List<MarkdownBlock>.unmodifiable(
        <MarkdownBlock>[
          MarkdownParagraph(<MarkdownInline>[
            MarkdownText('first ${'a' * 70000}'),
          ]),
        ],
      );
      final List<MarkdownBlock> second = <MarkdownBlock>[
        MarkdownParagraph(<MarkdownInline>[MarkdownText('second')]),
      ];
      List<MarkdownBlock> blocks = first;
      late StateSetter setBlocks;
      await pumpBodyAtWidth(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setBlocks = setState;
            return MqMarkdownRenderer(blocks: blocks);
          },
        ),
        480,
      );
      Finder paragraph(String prefix) => find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText && widget.text.toPlainText().startsWith(prefix),
      );
      expect(paragraph('first a'), findsOneWidget);
      expect(
        find.text('Preview limited to safe display bounds'),
        findsOneWidget,
      );

      setBlocks(() {});
      await tester.pump();
      expect(paragraph('first a'), findsOneWidget);
      expect(
        find.text('Preview limited to safe display bounds'),
        findsOneWidget,
      );

      setBlocks(() => blocks = second);
      await tester.pump();
      expect(paragraph('first'), findsNothing);
      expect(paragraph('second'), findsOneWidget);
      expect(find.text('Preview limited to safe display bounds'), findsNothing);
    },
  );
}
