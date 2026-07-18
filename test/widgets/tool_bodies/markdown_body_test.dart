import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/markdown_parser.dart';
import 'package:masquerade/widgets/mq/md_renderer.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/markdown_body.dart';
import 'package:masquerade/widgets/tool_bodies/seed_source.dart';

import '_helpers.dart';

void main() {
  String? clipboard;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders the common subset without Material or remote images', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const MarkdownBody(
        initialInput: '''
# Heading

**bold** and *soft*

- one
- two

> quote

| A | B |
| --- | --- |
| 1 | 2 |

![diagram](https://example.com/image.png)
''',
      ),
      480,
    );

    expect(find.text('Heading', findRichText: true), findsOneWidget);
    expect(find.text('quote', findRichText: true), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('[image: diagram]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('links and images only offer inert copy dialogs', (
    WidgetTester tester,
  ) async {
    const String url = 'https://example.com/docs';
    await pumpBodyAtWidth(
      tester,
      const MarkdownBody(initialInput: '[Docs]($url) and **bold**'),
      480,
    );

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(url), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, url);
  });

  testWidgets('long resource labels remain bounded at 180 px and 2x text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final String label = 'label' * 300;
    await pumpBodyAtWidth(
      tester,
      MarkdownBody(
        initialInput:
            '[$label](https://example.com)\n\n![$label](https://example.com/a.png)',
      ),
      180,
    );

    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fenced code keeps an exact copy value and bounded preview', (
    WidgetTester tester,
  ) async {
    final String code = '${'x' * 21000}\n  end  \n';
    await pumpBodyAtWidth(
      tester,
      MarkdownBody(initialInput: '```dart\n$code```'),
      480,
    );

    final MqMonoCell cell = tester.widget<MqMonoCell>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is MqMonoCell && widget.label == 'Code · dart',
      ),
    );
    expect(cell.value.length, lessThan(code.length));
    expect(cell.copyValue, code);
  });

  testWidgets('recursively caps rendered text on rune boundaries', (
    WidgetTester tester,
  ) async {
    final String long = '${'a' * 65535}😀tail';
    await pumpBodyAtWidth(
      tester,
      MqMarkdownRenderer(
        blocks: <MarkdownBlock>[
          MarkdownQuote(<MarkdownBlock>[
            MarkdownParagraph(<MarkdownInline>[MarkdownText(long)]),
          ]),
        ],
      ),
      480,
    );

    expect(find.text('Preview limited to safe display bounds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('globally caps nested zero-text blocks and table cells', (
    WidgetTester tester,
  ) async {
    final List<MarkdownInline> empty = const <MarkdownInline>[];
    await pumpBodyAtWidth(
      tester,
      MqMarkdownRenderer(
        blocks: <MarkdownBlock>[
          MarkdownQuote(<MarkdownBlock>[
            for (int index = 0; index < 600; index++) const MarkdownRule(),
          ]),
          MarkdownTable(
            header: <List<MarkdownInline>>[
              for (int column = 0; column < 100; column++) empty,
            ],
            rows: <List<List<MarkdownInline>>>[
              for (int row = 0; row < 60; row++)
                <List<MarkdownInline>>[
                  for (int column = 0; column < 100; column++) empty,
                ],
            ],
          ),
        ],
      ),
      480,
    );

    expect(find.text('Preview limited to safe display bounds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paste history records ordinary Markdown but skips secrets', (
    WidgetTester tester,
  ) async {
    final HistoryController history = HistoryController();
    await _pumpWithHistory(
      tester,
      history,
      const MarkdownBody(
        initialInput: '# Public\n\n**hello**',
        seedSource: SeedSource.paste,
      ),
    );
    expect(history.entries.single.utilityId, 'markdown');

    await _pumpWithHistory(
      tester,
      history,
      const MarkdownBody(
        key: ValueKey<String>('secret'),
        initialInput:
            '# Private\n\n[endpoint](https://user:password@example.com)',
        seedSource: SeedSource.paste,
      ),
    );
    expect(history.entries, hasLength(1));
  });
}

Future<void> _pumpWithHistory(
  WidgetTester tester,
  HistoryController history,
  Widget body,
) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: HistoryScope(
          controller: history,
          child: SingleChildScrollView(child: body),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
