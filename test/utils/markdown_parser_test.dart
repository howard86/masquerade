import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/markdown_parser.dart';

void main() {
  test('empty input is an empty document', () {
    final MarkdownOk result = MarkdownParser.parse('') as MarkdownOk;
    expect(result.blocks, isEmpty);
    expect(result.headings, isEmpty);
  });

  test('maps headings 1 through 6 and exposes heading text', () {
    final MarkdownOk result =
        MarkdownParser.parse(
              <String>[
                '# One',
                '## Two',
                '### Three',
                '#### Four',
                '##### Five',
                '###### Six',
              ].join('\n\n'),
            )
            as MarkdownOk;

    expect(
      result.blocks.whereType<MarkdownHeading>().map((node) => node.level),
      <int>[1, 2, 3, 4, 5, 6],
    );
    expect(result.headings, <String>[
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
    ]);
  });

  test('maps inline emphasis, code, links, and inert image data', () {
    final MarkdownOk result =
        MarkdownParser.parse(
              'Use **bold**, *soft*, `code`, [docs](https://example.com), and '
              '![diagram](https://example.com/a.png).',
            )
            as MarkdownOk;
    final List<MarkdownInline> nodes =
        (result.blocks.single as MarkdownParagraph).children;

    expect(nodes.whereType<MarkdownStrong>(), hasLength(1));
    expect(nodes.whereType<MarkdownEmphasis>(), hasLength(1));
    expect(nodes.whereType<MarkdownInlineCode>().single.code, 'code');
    expect(
      nodes.whereType<MarkdownLink>().single.destination,
      'https://example.com',
    );
    expect(nodes.whereType<MarkdownImage>().single.source, endsWith('a.png'));
  });

  test('preserves fenced code whitespace and language', () {
    final MarkdownOk result =
        MarkdownParser.parse('```dart\n  final x = 1;  \n\n```') as MarkdownOk;
    final MarkdownCodeBlock code = result.blocks.single as MarkdownCodeBlock;

    expect(code.language, 'dart');
    expect(code.code, '  final x = 1;  \n\n');
  });

  test('maps lists, quotes, rules, and GFM tables', () {
    final MarkdownOk result =
        MarkdownParser.parse('''
- first
- second

> quoted

---

| Name | Value |
| --- | ---: |
| Ada | 1 |
''')
            as MarkdownOk;

    expect(result.blocks.whereType<MarkdownList>().single.items, hasLength(2));
    expect(result.blocks.whereType<MarkdownQuote>(), hasLength(1));
    expect(result.blocks.whereType<MarkdownRule>(), hasLength(1));
    final MarkdownTable table = result.blocks.whereType<MarkdownTable>().single;
    expect(table.header, hasLength(2));
    expect(table.rows, hasLength(1));
  });

  test('enforces UTF-8 input and resource bounds without echoing input', () {
    expect(MarkdownParser.parse('😀' * 70000), isA<MarkdownErr>());
    final MarkdownErr resource =
        MarkdownParser.parse('[x](https://example.com/${'a' * 5000})')
            as MarkdownErr;
    expect(resource.message, isNot(contains('example.com')));
  });

  test('renders the repository README into the internal AST', () {
    final MarkdownParseResult result = MarkdownParser.parse(
      File('README.md').readAsStringSync(),
    );
    expect(result, isA<MarkdownOk>());
    expect((result as MarkdownOk).blocks, isNotEmpty);
  });
}
