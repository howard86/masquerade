import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/markdown_parser.dart';
import '../../utils/sensitive_data_policy.dart';
import 'mq_icons.dart';
import 'mq_mono_cell.dart';
import 'mq_surface.dart';

/// Cupertino-only renderer for Masquerade's bounded internal Markdown AST.
class MqMarkdownRenderer extends StatelessWidget {
  const MqMarkdownRenderer({super.key, required this.blocks});

  static const int _maxVisibleBlocks = 500;
  static const int _maxVisibleListItems = 200;
  static const int _maxVisibleTableRows = 100;
  static const int _maxVisibleTableColumns = 40;
  static const int _maxCodePreview = 20000;

  final List<MarkdownBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final _PreviewPlan plan = _PreviewPlanner().build(blocks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MarkdownBlock block in plan.blocks) ...<Widget>[
          _MarkdownBlockView(block: block),
          const SizedBox(height: MqSpacing.md),
        ],
        if (plan.truncated)
          const _LimitNotice(label: 'Preview limited to safe display bounds'),
      ],
    );
  }
}

class _MarkdownBlockView extends StatelessWidget {
  const _MarkdownBlockView({required this.block});

  final MarkdownBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    MarkdownHeading(:final level, :final children) => _InlineText(
      nodes: children,
      style: _headingStyle(level).copyWith(color: context.mq.colors.textPri),
    ),
    MarkdownParagraph(:final children) => _InlineText(
      nodes: children,
      style: MqTextStyles.body.copyWith(color: context.mq.colors.textPri),
    ),
    MarkdownCodeBlock(:final code, :final language, :final preview) =>
      MqMonoCell(
        label: language?.isNotEmpty == true ? 'Code · $language' : 'Code',
        value: _preview(preview ?? code, MqMarkdownRenderer._maxCodePreview),
        copyValue: code,
      ),
    MarkdownList(:final ordered, :final items) => _MarkdownListView(
      ordered: ordered,
      items: items,
    ),
    MarkdownQuote(:final blocks) => _MarkdownQuoteView(blocks: blocks),
    MarkdownRule() => Container(
      height: 1,
      color: context.mq.colors.borderStrong,
    ),
    MarkdownTable(:final header, :final rows) => _MarkdownTableView(
      header: header,
      rows: rows,
    ),
  };

  static TextStyle _headingStyle(int level) => switch (level) {
    1 => MqTextStyles.title1,
    2 => MqTextStyles.title2,
    3 => MqTextStyles.title3,
    4 => MqTextStyles.headline,
    5 => MqTextStyles.subhead.copyWith(fontWeight: FontWeight.w600),
    _ => MqTextStyles.footnote.copyWith(fontWeight: FontWeight.w600),
  };
}

class _InlineText extends StatelessWidget {
  const _InlineText({required this.nodes, required this.style});

  final List<MarkdownInline> nodes;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(style: style, children: _spans(context, nodes, style)),
  );

  static List<InlineSpan> _spans(
    BuildContext context,
    List<MarkdownInline> nodes,
    TextStyle base,
  ) => <InlineSpan>[
    for (final MarkdownInline node in nodes)
      switch (node) {
        MarkdownText(:final text) => TextSpan(text: text),
        MarkdownStrong(:final children) => TextSpan(
          style: base.copyWith(fontWeight: FontWeight.w700),
          children: _spans(
            context,
            children,
            base.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        MarkdownEmphasis(:final children) => TextSpan(
          style: base.copyWith(fontStyle: FontStyle.italic),
          children: _spans(
            context,
            children,
            base.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        MarkdownInlineCode(:final code) => TextSpan(
          text: code,
          style: MqTextStyles.monoSm.copyWith(
            color: context.mq.colors.monoText,
            backgroundColor: context.mq.colors.monoBg,
          ),
        ),
        MarkdownLink(:final destination, :final children) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ResourceButton(
            label: _inlinePlainText(children).isEmpty
                ? destination
                : _inlinePlainText(children),
            destination: destination,
            image: false,
          ),
        ),
        MarkdownImage(:final source, :final alt) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ResourceButton(
            label: alt.isEmpty ? 'image' : alt,
            destination: source,
            image: true,
          ),
        ),
        MarkdownLineBreak() => const TextSpan(text: '\n'),
      },
  ];
}

class _ResourceButton extends StatelessWidget {
  const _ResourceButton({
    required this.label,
    required this.destination,
    required this.image,
  });

  final String label;
  final String destination;
  final bool image;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      minimumSize: const Size(44, 44),
      onPressed: () => _showResource(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(image ? MqIcons.brackets : MqIcons.link, size: 13),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              image ? '[image: $label]' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MqTextStyles.callout.copyWith(
                color: context.mq.colors.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResource(BuildContext context) async {
    final bool sensitive =
        SensitiveDataPolicy.containsSensitiveArtifact(destination) ||
        SensitiveDataPolicy.containsSecretLikeValue(destination);
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text(image ? 'Image source' : 'Link'),
        content: Text(
          SensitiveDataPolicy.safePreview(
            destination,
            max: 512,
            sensitive: sensitive,
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          CupertinoDialogAction(
            onPressed: destination.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: destination));
                    HapticFeedback.selectionClick();
                    Navigator.of(dialogContext).pop();
                  },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _MarkdownListView extends StatelessWidget {
  const _MarkdownListView({required this.ordered, required this.items});

  final bool ordered;
  final List<List<MarkdownBlock>> items;

  @override
  Widget build(BuildContext context) {
    final List<List<MarkdownBlock>> visible = items
        .take(MqMarkdownRenderer._maxVisibleListItems)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int index, List<MarkdownBlock> blocks) in visible.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: Text(
                    ordered ? '${index + 1}.' : '•',
                    style: MqTextStyles.body.copyWith(
                      color: context.mq.colors.textSec,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final MarkdownBlock block in blocks)
                        _MarkdownBlockView(block: block),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (items.length > visible.length)
          _LimitNotice(
            label:
                'Showing ${MqMarkdownRenderer._maxVisibleListItems} of ${items.length} list items',
          ),
      ],
    );
  }
}

class _MarkdownQuoteView extends StatelessWidget {
  const _MarkdownQuoteView({required this.blocks});

  final List<MarkdownBlock> blocks;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: context.mq.colors.accent, width: 3),
      ),
    ),
    padding: const EdgeInsets.only(left: MqSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MarkdownBlock block in blocks)
          _MarkdownBlockView(block: block),
      ],
    ),
  );
}

class _MarkdownTableView extends StatefulWidget {
  const _MarkdownTableView({required this.header, required this.rows});

  final List<List<MarkdownInline>> header;
  final List<List<List<MarkdownInline>>> rows;

  @override
  State<_MarkdownTableView> createState() => _MarkdownTableViewState();
}

class _MarkdownTableViewState extends State<_MarkdownTableView> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int columns = <int>[
      widget.header.length,
      for (final List<List<MarkdownInline>> row in widget.rows) row.length,
    ].fold(0, (int largest, int value) => value > largest ? value : largest);
    final int visibleColumns =
        columns > MqMarkdownRenderer._maxVisibleTableColumns
        ? MqMarkdownRenderer._maxVisibleTableColumns
        : columns;
    final List<List<List<MarkdownInline>>> visibleRows = widget.rows
        .take(MqMarkdownRenderer._maxVisibleTableRows)
        .toList(growable: false);
    if (visibleColumns == 0) return const SizedBox.shrink();

    final List<List<List<MarkdownInline>>> tableRows =
        <List<List<MarkdownInline>>>[
          if (widget.header.isNotEmpty) widget.header,
          ...visibleRows,
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSurface(
          padded: false,
          child: CupertinoScrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: visibleColumns * 180,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(180),
                  border: TableBorder.all(
                    color: context.mq.colors.border,
                    width: .5,
                  ),
                  children: <TableRow>[
                    for (final (int rowIndex, List<List<MarkdownInline>> row)
                        in tableRows.indexed)
                      TableRow(
                        decoration: rowIndex == 0 && widget.header.isNotEmpty
                            ? BoxDecoration(color: context.mq.colors.surface2)
                            : null,
                        children: <Widget>[
                          for (
                            int column = 0;
                            column < visibleColumns;
                            column++
                          )
                            Padding(
                              padding: const EdgeInsets.all(MqSpacing.sm),
                              child: _InlineText(
                                nodes: column < row.length
                                    ? row[column]
                                    : const <MarkdownInline>[],
                                style: MqTextStyles.footnote.copyWith(
                                  color: context.mq.colors.textPri,
                                  fontWeight:
                                      rowIndex == 0 && widget.header.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.rows.length > visibleRows.length ||
            columns > visibleColumns) ...<Widget>[
          const SizedBox(height: MqSpacing.xs),
          _LimitNotice(
            label:
                'Previewing ${visibleRows.length}/${widget.rows.length} rows and $visibleColumns/$columns columns',
          ),
        ],
      ],
    );
  }
}

class _LimitNotice extends StatelessWidget {
  const _LimitNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: MqTextStyles.caption1.copyWith(color: context.mq.colors.textTer),
  );
}

String _inlinePlainText(List<MarkdownInline> nodes) {
  final StringBuffer output = StringBuffer();
  void visit(MarkdownInline node) {
    switch (node) {
      case MarkdownText(:final text):
        output.write(text);
      case MarkdownStrong(:final children) ||
          MarkdownEmphasis(:final children) ||
          MarkdownLink(:final children):
        for (final MarkdownInline child in children) {
          visit(child);
        }
      case MarkdownInlineCode(:final code):
        output.write(code);
      case MarkdownImage(:final alt):
        output.write(alt);
      case MarkdownLineBreak():
        output.write(' ');
    }
  }

  for (final MarkdownInline node in nodes) {
    visit(node);
  }
  return output.toString();
}

String _preview(String value, int max) {
  final List<int> runes = value.runes.toList(growable: false);
  if (runes.length <= max) return value;
  return '${String.fromCharCodes(runes.take(max))}\n… ${runes.length - max} characters hidden';
}

final class _PreviewPlan {
  const _PreviewPlan({required this.blocks, required this.truncated});

  final List<MarkdownBlock> blocks;
  final bool truncated;
}

final class _PreviewPlanner {
  static const int _maxVisibleRunes = 64 * 1024;
  static const int _maxVisibleElements = 5000;

  int _remaining = _maxVisibleRunes;
  int _remainingBlocks = MqMarkdownRenderer._maxVisibleBlocks;
  int _remainingListItems = MqMarkdownRenderer._maxVisibleListItems;
  int _remainingTableCells = 2000;
  int _remainingElements = _maxVisibleElements;
  bool _truncated = false;

  _PreviewPlan build(List<MarkdownBlock> source) {
    final List<MarkdownBlock> result = _blocks(source);
    return _PreviewPlan(
      blocks: List<MarkdownBlock>.unmodifiable(result),
      truncated: _truncated,
    );
  }

  List<MarkdownBlock> _blocks(Iterable<MarkdownBlock> source) {
    final List<MarkdownBlock> result = <MarkdownBlock>[];
    for (final MarkdownBlock block in source) {
      if (_remaining <= 0 || _remainingBlocks <= 0 || !_element()) {
        _truncated = true;
        break;
      }
      _remainingBlocks--;
      final MarkdownBlock? visible = _block(block);
      if (visible != null) result.add(visible);
    }
    return result;
  }

  MarkdownBlock? _block(MarkdownBlock block) => switch (block) {
    MarkdownHeading(:final level, :final children) => MarkdownHeading(
      level,
      _inlines(children),
    ),
    MarkdownParagraph(:final children) => MarkdownParagraph(_inlines(children)),
    MarkdownCodeBlock(:final code, :final language) => _code(code, language),
    MarkdownList(:final ordered, :final items) => _list(ordered, items),
    MarkdownQuote(:final blocks) => MarkdownQuote(_blocks(blocks)),
    MarkdownRule() => const MarkdownRule(),
    MarkdownTable(:final header, :final rows) => _table(header, rows),
  };

  MarkdownCodeBlock _code(String code, String? language) {
    final List<int> runes = code.runes.toList(growable: false);
    final int cap = runes.length > MqMarkdownRenderer._maxCodePreview
        ? MqMarkdownRenderer._maxCodePreview
        : runes.length;
    final int take = cap > _remaining ? _remaining : cap;
    _remaining -= take;
    final bool shortened = take < runes.length;
    if (shortened) _truncated = true;
    final String preview = String.fromCharCodes(runes.take(take));
    return MarkdownCodeBlock(
      code,
      language,
      preview: shortened ? '$preview…' : preview,
    );
  }

  MarkdownList _list(bool ordered, List<List<MarkdownBlock>> items) {
    final List<List<MarkdownBlock>> visible = <List<MarkdownBlock>>[];
    for (final List<MarkdownBlock> item in items.take(
      MqMarkdownRenderer._maxVisibleListItems,
    )) {
      if (_remaining <= 0 || _remainingListItems <= 0 || !_element()) break;
      _remainingListItems--;
      visible.add(List<MarkdownBlock>.unmodifiable(_blocks(item)));
    }
    if (visible.length < items.length) _truncated = true;
    return MarkdownList(ordered: ordered, items: List.unmodifiable(visible));
  }

  MarkdownTable _table(
    List<List<MarkdownInline>> header,
    List<List<List<MarkdownInline>>> rows,
  ) {
    final List<List<MarkdownInline>> visibleHeader = <List<MarkdownInline>>[];
    for (final List<MarkdownInline> cell in header.take(
      MqMarkdownRenderer._maxVisibleTableColumns,
    )) {
      if (!_tableCell()) break;
      visibleHeader.add(_inlines(cell));
    }
    final List<List<List<MarkdownInline>>> visibleRows =
        <List<List<MarkdownInline>>>[];
    for (final List<List<MarkdownInline>> row in rows.take(
      MqMarkdownRenderer._maxVisibleTableRows,
    )) {
      if (_remaining <= 0) break;
      final List<List<MarkdownInline>> visibleRow = <List<MarkdownInline>>[];
      for (final List<MarkdownInline> cell in row.take(
        MqMarkdownRenderer._maxVisibleTableColumns,
      )) {
        if (!_tableCell()) break;
        visibleRow.add(_inlines(cell));
      }
      if (visibleRow.isEmpty && row.isNotEmpty) break;
      visibleRows.add(visibleRow);
    }
    if (visibleHeader.length < header.length ||
        visibleRows.length < rows.length) {
      _truncated = true;
    }
    return MarkdownTable(header: visibleHeader, rows: visibleRows);
  }

  List<MarkdownInline> _inlines(List<MarkdownInline> source) {
    final List<MarkdownInline> result = <MarkdownInline>[];
    for (final MarkdownInline inline in source) {
      if (_remaining <= 0 || !_element()) {
        _truncated = true;
        break;
      }
      switch (inline) {
        case MarkdownText(:final text):
          final String visible = _take(text);
          if (visible.isNotEmpty) result.add(MarkdownText(visible));
        case MarkdownStrong(:final children):
          result.add(MarkdownStrong(_inlines(children)));
        case MarkdownEmphasis(:final children):
          result.add(MarkdownEmphasis(_inlines(children)));
        case MarkdownInlineCode(:final code):
          final String visible = _take(code);
          if (visible.isNotEmpty) result.add(MarkdownInlineCode(visible));
        case MarkdownLink(:final destination, :final children):
          result.add(
            MarkdownLink(
              destination: destination,
              children: _inlines(children),
            ),
          );
        case MarkdownImage(:final source, :final alt):
          result.add(MarkdownImage(source: source, alt: _take(alt)));
        case MarkdownLineBreak():
          _remaining--;
          result.add(const MarkdownLineBreak());
      }
    }
    return List<MarkdownInline>.unmodifiable(result);
  }

  bool _tableCell() {
    if (_remainingTableCells <= 0 || !_element()) {
      _truncated = true;
      return false;
    }
    _remainingTableCells--;
    return true;
  }

  bool _element() {
    if (_remainingElements <= 0) return false;
    _remainingElements--;
    return true;
  }

  String _take(String value) {
    final List<int> runes = value.runes.toList(growable: false);
    if (runes.length <= _remaining) {
      _remaining -= runes.length;
      return value;
    }
    final String visible = String.fromCharCodes(runes.take(_remaining));
    _remaining = 0;
    _truncated = true;
    return '$visible…';
  }
}
