import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

sealed class MarkdownParseResult {
  const MarkdownParseResult();
}

final class MarkdownOk extends MarkdownParseResult {
  const MarkdownOk({required this.blocks, required this.headings});

  final List<MarkdownBlock> blocks;
  final List<String> headings;
}

final class MarkdownErr extends MarkdownParseResult {
  const MarkdownErr(this.message);

  final String message;
}

sealed class MarkdownBlock {
  const MarkdownBlock();
}

final class MarkdownHeading extends MarkdownBlock {
  const MarkdownHeading(this.level, this.children);

  final int level;
  final List<MarkdownInline> children;
}

final class MarkdownParagraph extends MarkdownBlock {
  const MarkdownParagraph(this.children);

  final List<MarkdownInline> children;
}

final class MarkdownCodeBlock extends MarkdownBlock {
  const MarkdownCodeBlock(this.code, this.language, {this.preview});

  final String code;
  final String? language;
  final String? preview;
}

final class MarkdownList extends MarkdownBlock {
  const MarkdownList({required this.ordered, required this.items});

  final bool ordered;
  final List<List<MarkdownBlock>> items;
}

final class MarkdownQuote extends MarkdownBlock {
  const MarkdownQuote(this.blocks);

  final List<MarkdownBlock> blocks;
}

final class MarkdownRule extends MarkdownBlock {
  const MarkdownRule();
}

final class MarkdownTable extends MarkdownBlock {
  const MarkdownTable({required this.header, required this.rows});

  final List<List<MarkdownInline>> header;
  final List<List<List<MarkdownInline>>> rows;
}

sealed class MarkdownInline {
  const MarkdownInline();
}

final class MarkdownText extends MarkdownInline {
  const MarkdownText(this.text);

  final String text;
}

final class MarkdownStrong extends MarkdownInline {
  const MarkdownStrong(this.children);

  final List<MarkdownInline> children;
}

final class MarkdownEmphasis extends MarkdownInline {
  const MarkdownEmphasis(this.children);

  final List<MarkdownInline> children;
}

final class MarkdownInlineCode extends MarkdownInline {
  const MarkdownInlineCode(this.code);

  final String code;
}

final class MarkdownLink extends MarkdownInline {
  const MarkdownLink({required this.destination, required this.children});

  final String destination;
  final List<MarkdownInline> children;
}

final class MarkdownImage extends MarkdownInline {
  const MarkdownImage({required this.source, required this.alt});

  final String source;
  final String alt;
}

final class MarkdownLineBreak extends MarkdownInline {
  const MarkdownLineBreak();
}

class MarkdownParser {
  const MarkdownParser._();

  static const int maxInputBytes = 256 * 1024;
  static const int maxNodes = 10000;
  static const int maxDepth = 32;
  static const int maxTextCharacters = 512 * 1024;
  static const int maxCodeCharacters = 128 * 1024;
  static const int maxListItems = 2000;
  static const int maxTableRows = 1000;
  static const int maxTableColumns = 100;
  static const int maxResourceCharacters = 4096;

  static MarkdownParseResult parse(String input) {
    if (input.isEmpty) {
      return const MarkdownOk(blocks: <MarkdownBlock>[], headings: <String>[]);
    }
    if (input.length > maxInputBytes) {
      return const MarkdownErr('Markdown input is limited to 256 KiB.');
    }
    if (utf8.encode(input).length > maxInputBytes) {
      return const MarkdownErr('Markdown input is limited to 256 KiB.');
    }
    try {
      final List<md.Node> source = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
      ).parse(input);
      final _MarkdownMapper mapper = _MarkdownMapper();
      return MarkdownOk(
        blocks: List<MarkdownBlock>.unmodifiable(mapper.blocks(source, 0)),
        headings: List<String>.unmodifiable(mapper.headings),
      );
    } on _MarkdownLimit catch (error) {
      return MarkdownErr(error.message);
    } on Object {
      return const MarkdownErr('Could not parse this Markdown document.');
    }
  }
}

final class _MarkdownMapper {
  final List<String> headings = <String>[];
  int _nodes = 0;
  int _textCharacters = 0;
  int _listItems = 0;
  int _tableRows = 0;

  List<MarkdownBlock> blocks(List<md.Node> nodes, int depth) {
    _checkDepth(depth);
    final List<MarkdownBlock> result = <MarkdownBlock>[];
    for (final md.Node node in nodes) {
      if (node case final md.Text text) {
        if (text.text.trim().isNotEmpty) {
          result.add(
            _node(MarkdownParagraph(inlines(<md.Node>[text], depth + 1))),
          );
        }
        continue;
      }
      final md.Element element = node as md.Element;
      final List<md.Node> children = element.children ?? const <md.Node>[];
      switch (element.tag) {
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          final List<MarkdownInline> content = inlines(children, depth + 1);
          headings.add(_plainText(content));
          result.add(
            _node(
              MarkdownHeading(int.parse(element.tag.substring(1)), content),
            ),
          );
        case 'p':
          result.add(_node(MarkdownParagraph(inlines(children, depth + 1))));
        case 'pre':
          result.add(_codeBlock(element));
        case 'ul' || 'ol':
          result.add(_list(element, depth + 1));
        case 'blockquote':
          result.add(_node(MarkdownQuote(blocks(children, depth + 1))));
        case 'hr':
          result.add(_node(const MarkdownRule()));
        case 'table':
          result.add(_table(element, depth + 1));
        default:
          if (_containsBlock(children)) {
            result.addAll(blocks(children, depth + 1));
          } else if (element.textContent.trim().isNotEmpty) {
            result.add(_node(MarkdownParagraph(inlines(children, depth + 1))));
          }
      }
    }
    return result;
  }

  List<MarkdownInline> inlines(List<md.Node> nodes, int depth) {
    _checkDepth(depth);
    final List<MarkdownInline> result = <MarkdownInline>[];
    for (final md.Node node in nodes) {
      if (node case final md.Text text) {
        if (text.text.isNotEmpty) {
          _addText(text.text);
          result.add(_node(MarkdownText(text.text)));
        }
        continue;
      }
      final md.Element element = node as md.Element;
      final List<md.Node> children = element.children ?? const <md.Node>[];
      switch (element.tag) {
        case 'strong' || 'b':
          result.add(_node(MarkdownStrong(inlines(children, depth + 1))));
        case 'em' || 'i':
          result.add(_node(MarkdownEmphasis(inlines(children, depth + 1))));
        case 'code':
          _addCode(element.textContent);
          result.add(_node(MarkdownInlineCode(element.textContent)));
        case 'a':
          final String destination = _resource(element.attributes['href']);
          result.add(
            _node(
              MarkdownLink(
                destination: destination,
                children: inlines(children, depth + 1),
              ),
            ),
          );
        case 'img':
          final String source = _resource(element.attributes['src']);
          final String alt = element.attributes['alt'] ?? element.textContent;
          _addText(alt);
          result.add(_node(MarkdownImage(source: source, alt: alt)));
        case 'br':
          result.add(_node(const MarkdownLineBreak()));
        default:
          result.addAll(inlines(children, depth + 1));
      }
    }
    return List<MarkdownInline>.unmodifiable(result);
  }

  MarkdownCodeBlock _codeBlock(md.Element element) {
    final md.Element? code = (element.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .firstOrNull;
    final String value = code?.textContent ?? element.textContent;
    _addCode(value);
    final String? className = code?.attributes['class'];
    final String? language = className?.startsWith('language-') == true
        ? className!.substring('language-'.length)
        : null;
    return _node(MarkdownCodeBlock(value, language));
  }

  MarkdownList _list(md.Element element, int depth) {
    _checkDepth(depth);
    final List<List<MarkdownBlock>> items = <List<MarkdownBlock>>[];
    for (final md.Element item
        in (element.children ?? const <md.Node>[])
            .whereType<md.Element>()
            .where((md.Element child) => child.tag == 'li')) {
      _listItems++;
      if (_listItems > MarkdownParser.maxListItems) {
        throw const _MarkdownLimit(
          'Markdown lists are limited to 2,000 items.',
        );
      }
      items.add(
        List<MarkdownBlock>.unmodifiable(blocks(_listChildren(item), depth)),
      );
    }
    return _node(
      MarkdownList(
        ordered: element.tag == 'ol',
        items: List.unmodifiable(items),
      ),
    );
  }

  List<md.Node> _listChildren(md.Element item) {
    final List<md.Node> children = item.children ?? const <md.Node>[];
    if (_containsBlock(children)) return children;
    return <md.Node>[md.Element('p', children)];
  }

  MarkdownTable _table(md.Element table, int depth) {
    _checkDepth(depth);
    List<List<MarkdownInline>> header = const <List<MarkdownInline>>[];
    final List<List<List<MarkdownInline>>> rows =
        <List<List<MarkdownInline>>>[];
    for (final md.Element section
        in (table.children ?? const <md.Node>[]).whereType<md.Element>()) {
      for (final md.Element row
          in (section.children ?? const <md.Node>[])
              .whereType<md.Element>()
              .where((md.Element child) => child.tag == 'tr')) {
        _tableRows++;
        if (_tableRows > MarkdownParser.maxTableRows) {
          throw const _MarkdownLimit(
            'Markdown tables are limited to 1,000 rows.',
          );
        }
        final List<md.Element> cells = (row.children ?? const <md.Node>[])
            .whereType<md.Element>()
            .where((md.Element child) => child.tag == 'th' || child.tag == 'td')
            .toList(growable: false);
        if (cells.length > MarkdownParser.maxTableColumns) {
          throw const _MarkdownLimit(
            'Markdown tables are limited to 100 columns.',
          );
        }
        final List<List<MarkdownInline>> converted = cells
            .map(
              (md.Element cell) =>
                  inlines(cell.children ?? const <md.Node>[], depth + 1),
            )
            .toList(growable: false);
        if (section.tag == 'thead' && header.isEmpty) {
          header = converted;
        } else {
          rows.add(converted);
        }
      }
    }
    return _node(
      MarkdownTable(
        header: List<List<MarkdownInline>>.unmodifiable(header),
        rows: List<List<List<MarkdownInline>>>.unmodifiable(rows),
      ),
    );
  }

  bool _containsBlock(List<md.Node> nodes) => nodes.whereType<md.Element>().any(
    (md.Element element) => const <String>{
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'pre',
      'ul',
      'ol',
      'blockquote',
      'hr',
      'table',
    }.contains(element.tag),
  );

  T _node<T>(T value) {
    _nodes++;
    if (_nodes > MarkdownParser.maxNodes) {
      throw const _MarkdownLimit(
        'Markdown documents are limited to 10,000 elements.',
      );
    }
    return value;
  }

  void _checkDepth(int depth) {
    if (depth > MarkdownParser.maxDepth) {
      throw const _MarkdownLimit('Markdown nesting is limited to 32 levels.');
    }
  }

  void _addText(String text) {
    _textCharacters += text.length;
    if (_textCharacters > MarkdownParser.maxTextCharacters) {
      throw const _MarkdownLimit('Markdown text is too large to preview.');
    }
  }

  void _addCode(String code) {
    if (code.length > MarkdownParser.maxCodeCharacters) {
      throw const _MarkdownLimit(
        'Each Markdown code block is limited to 128 KiB.',
      );
    }
    _addText(code);
  }

  String _resource(String? value) {
    final String result = value ?? '';
    if (result.length > MarkdownParser.maxResourceCharacters) {
      throw const _MarkdownLimit(
        'Markdown link and image destinations are limited to 4,096 characters.',
      );
    }
    _addText(result);
    return result;
  }

  String _plainText(List<MarkdownInline> nodes) {
    final StringBuffer result = StringBuffer();
    void visit(MarkdownInline node) {
      switch (node) {
        case MarkdownText(:final text):
          result.write(text);
        case MarkdownStrong(:final children) ||
            MarkdownEmphasis(:final children) ||
            MarkdownLink(:final children):
          for (final MarkdownInline child in children) {
            visit(child);
          }
        case MarkdownInlineCode(:final code):
          result.write(code);
        case MarkdownImage(:final alt):
          result.write(alt);
        case MarkdownLineBreak():
          result.write(' ');
      }
    }

    for (final MarkdownInline node in nodes) {
      visit(node);
    }
    return result.toString();
  }
}

final class _MarkdownLimit implements Exception {
  const _MarkdownLimit(this.message);

  final String message;
}
