import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../state/tool_draft_controller.dart';
import '../../theme/mq_colors.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/copy_util.dart';
import '../../utils/diff_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_layout.dart';

/// Diff · compare two texts. Line-level Myers diff rendered delta-style:
/// old/new gutters, red/green row washes, intra-line word highlighting, and
/// collapsed unchanged context that expands on tap. Copy emits a standard
/// unified diff.
class DiffBody extends StatefulWidget {
  const DiffBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.actionBar,
    this.link,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final ToolActionBarController? actionBar;

  /// Non-null when this card is in a canvas Link group. Diff is a two-input
  /// tool; the canonical drives **side A** (the original text), so a list ↔
  /// diff link feeds the list's text into A while B stays the user's local
  /// comparison (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<DiffBody> createState() => _DiffBodyState();
}

class _DiffBodyState extends State<DiffBody> with LinkableToolBody<DiffBody> {
  final TextEditingController _a = TextEditingController();
  final TextEditingController _b = TextEditingController();
  final FocusNode _aFocus = FocusNode();
  final FocusNode _bFocus = FocusNode();
  Timer? _debounce;

  bool _wordHighlight = true;
  bool _ignoreWhitespace = false;

  DiffResult? _result;
  List<DiffHunk> _hunks = const <DiffHunk>[];
  // line index -> word spans, pre-filtered for that line's side.
  final Map<int, List<WordSpan>> _spans = <int, List<WordSpan>>{};
  final Set<int> _expanded = <int>{};
  String _unified = '';

  HistoryRecorder? _recorder;
  ToolDraftController? _drafts;
  bool _draftRestored = false;
  int? _draftRevision;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _a.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _convert();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
  }

  // ─── Canonical-hub link (side-A text canonical) ─────────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical is side A's text (the original); side B is the user's local
  /// comparison and stays out of the group.
  @override
  String currentCanonical() => _a.text;

  @override
  void applyInbound(String canonical) {
    _a.text = canonical;
    _convert();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.read(context),
        utilityId: 'diff',
        sensitive:
            MobileSessionRouteScope.maybeOf(context)?.protectedSession ?? false,
      );
      if (widget.seedSource == SeedSource.paste) {
        _recorder!.markPaste();
      }
    }
    _drafts ??= ToolDraftScope.maybeOf(context);
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    final ToolDraftController? drafts = _drafts;
    if (!_draftRestored && route != null && drafts != null && drafts.ready) {
      _draftRevision = drafts.revision;
      _draftRestored = true;
      final DiffToolDraft? draft = drafts.diff;
      final Object? savedWordHighlight = route.settings['wordHighlight'];
      final Object? savedIgnoreWhitespace = route.settings['ignoreWhitespace'];
      _wordHighlight = savedWordHighlight is bool
          ? savedWordHighlight
          : draft?.wordHighlight ?? _wordHighlight;
      _ignoreWhitespace = savedIgnoreWhitespace is bool
          ? savedIgnoreWhitespace
          : draft?.ignoreWhitespace ?? _ignoreWhitespace;
      if (draft != null) {
        if ((widget.initialInput == null || widget.initialInput!.isEmpty) &&
            !route.protectedSession) {
          _a.text = draft.a;
          _b.text = draft.b;
        }
        if (_a.text.isNotEmpty || _b.text.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _convert();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    _a.dispose();
    _b.dispose();
    _aFocus.dispose();
    _bFocus.dispose();
    super.dispose();
  }

  bool get _canSwap => _a.text.isNotEmpty || _b.text.isNotEmpty;

  void _updateActionBar() {
    // No global Paste — each field uses native paste; Diff binds Clear + Swap.
    widget.actionBar?.bind(
      onClear: _clear,
      center: MqButton(
        label: 'Swap A↔B',
        icon: MqIcons.swap,
        variant: MqButtonVariant.glass,
        onPressed: _canSwap ? _swap : null,
        full: true,
      ),
    );
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _convert);
    _saveDraft();
  }

  void _convert() {
    final String aText = _a.text;
    final String bText = _b.text;
    final DiffResult result = DiffTool.lineDiff(
      aText,
      bText,
      ignoreWhitespace: _ignoreWhitespace,
    );
    final List<DiffHunk> hunks = result.tooLarge
        ? const <DiffHunk>[]
        : DiffTool.hunkify(result.lines);
    final String unified = result.tooLarge
        ? ''
        : DiffTool.toUnifiedText(
            result,
            aLabel: 'A',
            bLabel: 'B',
            hunks: hunks,
          );

    _spans.clear();
    _expanded.clear();
    if (_wordHighlight && !result.tooLarge) {
      _computeSpans(result.lines);
    }

    setState(() {
      _result = result;
      _hunks = hunks;
      _unified = unified;
    });

    if (unified.isNotEmpty) {
      _recorder?.record(aText, unified);
    }
    _saveDraft();
    _updateActionBar();
    // Only side A is the canonical; an emit after a B-only edit is a no-op.
    emitToLink();
  }

  // Pairs the k-th deleted line with the k-th inserted line inside each change
  // run and stores per-line word spans (delta's intra-line highlighting).
  void _computeSpans(List<DiffLine> lines) {
    int i = 0;
    while (i < lines.length) {
      if (lines[i].op == DiffOp.equal) {
        i++;
        continue;
      }
      final int start = i;
      while (i < lines.length && lines[i].op != DiffOp.equal) {
        i++;
      }
      final List<int> dels = <int>[];
      final List<int> ins = <int>[];
      for (int j = start; j < i; j++) {
        (lines[j].op == DiffOp.delete ? dels : ins).add(j);
      }
      final int pairs = dels.length < ins.length ? dels.length : ins.length;
      for (int p = 0; p < pairs; p++) {
        final List<WordSpan> wd = DiffTool.wordDiff(
          lines[dels[p]].text,
          lines[ins[p]].text,
        );
        _spans[dels[p]] = wd
            .where((WordSpan s) => s.op != DiffOp.insert)
            .toList();
        _spans[ins[p]] = wd
            .where((WordSpan s) => s.op != DiffOp.delete)
            .toList();
      }
    }
  }

  // Word highlight only changes the per-line spans, so a toggle reuses the
  // current line diff instead of re-running it.
  void _respan() {
    final DiffResult? result = _result;
    if (result == null) {
      _convert();
      return;
    }
    setState(() {
      _spans.clear();
      _expanded.clear();
      if (_wordHighlight && !result.tooLarge) _computeSpans(result.lines);
    });
  }

  void _clear() {
    _a.clear();
    _b.clear();
    _spans.clear();
    _expanded.clear();
    setState(() {
      _result = null;
      _hunks = const <DiffHunk>[];
      _unified = '';
    });
    _saveDraft();
    _updateActionBar();
  }

  void _swap() {
    final String aText = _a.text;
    _a.text = _b.text;
    _b.text = aText;
    _recorder?.markPaste();
    _saveDraft();
    _convert();
  }

  void _saveDraft() {
    final ToolDraftController? drafts = _drafts;
    final int? revision = _draftRevision;
    final MobileSessionRouteScope? route = MobileSessionRouteScope.maybeOf(
      context,
    );
    route?.onSettingsChanged?.call(<String, Object?>{
      'wordHighlight': _wordHighlight,
      'ignoreWhitespace': _ignoreWhitespace,
    });
    if (drafts == null ||
        !drafts.ready ||
        route == null ||
        route.protectedSession ||
        revision == null) {
      return;
    }
    unawaited(
      drafts.saveDiff(
        a: _a.text,
        b: _b.text,
        wordHighlight: _wordHighlight,
        ignoreWhitespace: _ignoreWhitespace,
        revision: revision,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DiffResult? result = _result;
    final bool bothEmpty = _a.text.isEmpty && _b.text.isEmpty;

    final Widget aInput = MqInput(
      controller: _a,
      focusNode: _aFocus,
      label: 'A · original',
      placeholder: 'Paste the original text',
      onChanged: _onChanged,
      onPaste: (_) => _recorder?.markPaste(),
      multiline: true,
      minLines: 3,
      maxLines: 6,
    );
    final Widget bInput = MqInput(
      controller: _b,
      focusNode: _bFocus,
      label: 'B · changed',
      placeholder: 'Paste the changed text',
      onChanged: _onChanged,
      onPaste: (_) => _recorder?.markPaste(),
      multiline: true,
      minLines: 3,
      maxLines: 6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Canvas-wide: the two inputs sit side-by-side (A ‖ B). Below 460 they
        // stack — identical to the phone layout.
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth >= kToolCanvasWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: aInput),
                  const SizedBox(width: MqSpacing.md),
                  Expanded(child: bInput),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                aInput,
                const SizedBox(height: MqSpacing.md),
                bInput,
              ],
            );
          },
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            MqChip(
              label: 'Word highlight',
              mono: false,
              selected: _wordHighlight,
              onTap: () {
                _wordHighlight = !_wordHighlight;
                _saveDraft();
                _respan();
              },
            ),
            MqChip(
              label: 'Ignore whitespace',
              mono: false,
              selected: _ignoreWhitespace,
              onTap: () {
                _ignoreWhitespace = !_ignoreWhitespace;
                _saveDraft();
                _convert();
              },
            ),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        if (result != null && result.tooLarge)
          const MqEmptyHint(
            label:
                'Inputs too large to diff (over 5000 lines per side). '
                'Try smaller selections.',
          )
        else if (result == null || bothEmpty)
          const MqEmptyHint(label: 'Paste or type into A and B to compare.')
        else if (result.additions == 0 && result.deletions == 0)
          const MqEmptyHint(label: 'No differences — A and B are identical.')
        else ...<Widget>[
          _SummaryBar(
            additions: result.additions,
            deletions: result.deletions,
            unified: _unified,
          ),
          const SizedBox(height: MqSpacing.sm),
          _buildDiffView(result.lines),
        ],
      ],
    );
  }

  /// Above this many rows the diff view is virtualized: a lazily built list
  /// in a bounded viewport ([_virtualHeight]) instead of every row laid out
  /// at once inside the page's scroll.
  static const int _virtualizeAbove = 300;
  static const double _virtualHeight = 480;

  // Content-width memo for the virtualized view: one TextPainter pass over
  // the longest lines instead of IntrinsicWidth over every row.
  List<DiffLine>? _widthLines;
  TextScaler? _widthScaler;
  double _lineWidth = 0;

  Widget _buildDiffView(List<DiffLine> lines) {
    final c = context.mq.colors;
    final _DiffStyles styles = _DiffStyles(c);
    final List<_DiffItem> items = <_DiffItem>[];
    int cursor = 0;
    for (final DiffHunk h in _hunks) {
      _emitGap(items, cursor, h.startIndex);
      for (int idx = h.startIndex; idx < h.endIndex; idx++) {
        items.add(_DiffItem.line(idx, spans: true));
      }
      cursor = h.endIndex;
    }
    _emitGap(items, cursor, lines.length);

    Widget row(_DiffItem item) => item.gap > 0
        ? _CollapseDivider(
            count: item.gap,
            onTap: () => setState(() => _expanded.add(item.index)),
          )
        : _DiffRow(
            line: lines[item.index],
            spans: item.spans ? _spans[item.index] : null,
            styles: styles,
          );

    final Widget body;
    if (items.length <= _virtualizeAbove) {
      // Lines stay single-line and the body scrolls horizontally so the
      // old/new gutters stay column-aligned. IntrinsicWidth sizes every row
      // to the widest line so the red/green washes span the full scrolled
      // width rather than stopping at the viewport edge.
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[for (final _DiffItem item in items) row(item)],
          ),
        ),
      );
    } else {
      // Large diffs: only visible rows are built. The scrolled width comes
      // from measuring the longest lines once (not IntrinsicWidth over every
      // row) so the washes still span it.
      final double contentWidth =
          _DiffRow.chromeWidth + _measureLines(lines, styles.mono);
      body = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = contentWidth > constraints.maxWidth
              ? contentWidth
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: _virtualHeight,
              child: ListView.builder(
                key: const ValueKey<String>('diff-virtual-list'),
                primary: false,
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) =>
                    row(items[index]),
              ),
            ),
          );
        },
      );
    }

    return MqSurface(
      padded: false,
      background: c.monoBg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MqRadius.md),
        child: body,
      ),
    );
  }

  /// Widest rendered line, measured on the few longest lines by length (a
  /// shorter line of wide glyphs can still win, hence more than one). Lines
  /// a hair wider than the estimate clip rather than overflow.
  double _measureLines(List<DiffLine> lines, TextStyle mono) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    if (identical(_widthLines, lines) && _widthScaler == scaler) {
      return _lineWidth;
    }
    const int candidates = 8;
    final List<String> longest = <String>[];
    for (final DiffLine line in lines) {
      final String text = line.text;
      if (longest.length < candidates) {
        longest.add(text);
        longest.sort((String a, String b) => b.length.compareTo(a.length));
      } else if (text.length > longest.last.length) {
        longest[candidates - 1] = text;
        longest.sort((String a, String b) => b.length.compareTo(a.length));
      }
    }
    double width = 0;
    for (final String text in longest) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: mono.copyWith(fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    _widthLines = lines;
    _widthScaler = scaler;
    _lineWidth = width.ceilToDouble();
    return _lineWidth;
  }

  void _emitGap(List<_DiffItem> items, int from, int to) {
    if (to <= from) return;
    if (_expanded.contains(from)) {
      for (int idx = from; idx < to; idx++) {
        items.add(_DiffItem.line(idx, spans: false));
      }
    } else {
      items.add(_DiffItem.gap(from, to - from));
    }
  }
}

/// One row of the diff view: a line (with or without word spans) or a
/// collapsed run of [gap] unchanged lines starting at [index].
class _DiffItem {
  const _DiffItem.line(this.index, {required this.spans}) : gap = 0;
  const _DiffItem.gap(this.index, this.gap) : spans = false;

  final int index;
  final int gap;
  final bool spans;
}

/// Row text styles, built once per diff build rather than per row/span.
class _DiffStyles {
  _DiffStyles(MqColors c)
    : mono = MqTextStyles.monoSm.copyWith(color: c.monoText),
      deleteWord = MqTextStyles.monoSm.copyWith(
        color: c.onTint,
        backgroundColor: c.danger,
        fontWeight: FontWeight.w600,
      ),
      insertWord = MqTextStyles.monoSm.copyWith(
        color: c.onTint,
        backgroundColor: c.success,
        fontWeight: FontWeight.w600,
      ),
      deleteMark = MqTextStyles.monoSm.copyWith(color: c.danger),
      insertMark = MqTextStyles.monoSm.copyWith(color: c.success),
      equalMark = MqTextStyles.monoSm.copyWith(color: c.textTer),
      gutter = MqTextStyles.monoSm.copyWith(color: c.textTer),
      deleteBg = c.dangerBg,
      insertBg = c.successBg;

  final TextStyle mono;
  final TextStyle deleteWord;
  final TextStyle insertWord;
  final TextStyle deleteMark;
  final TextStyle insertMark;
  final TextStyle equalMark;
  final TextStyle gutter;
  final Color deleteBg;
  final Color insertBg;
}

/// `+N additions  −M deletions` with a copy-unified-diff affordance.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.additions,
    required this.deletions,
    required this.unified,
  });

  final int additions;
  final int deletions;
  final String unified;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final TextStyle base = MqTextStyles.monoSm.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: <Widget>[
        Text('+$additions', style: base.copyWith(color: c.success)),
        const SizedBox(width: MqSpacing.md),
        Text('−$deletions', style: base.copyWith(color: c.danger)),
        const Spacer(),
        AnimatedCopyIcon(
          onCopy: () => CopyToClipboardUtil.copyToClipboard(context, unified),
        ),
      ],
    );
  }
}

/// Tappable "⋯ N unchanged lines" row that reveals the hidden context.
class _CollapseDivider extends StatelessWidget {
  const _CollapseDivider({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String lines = count == 1 ? 'line' : 'lines';
    void expand() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      label: 'Expand $count unchanged $lines',
      onTap: expand,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        borderRadius: BorderRadius.zero,
        onPressed: expand,
        child: Container(
          color: c.surface2,
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(MqIcons.chevD, size: 13, color: c.textTer),
              const SizedBox(width: 6),
              Text(
                '$count unchanged $lines',
                style: MqTextStyles.caption1.copyWith(color: c.textTer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rendered diff line: old/new gutters, marker, and (optionally word-level
/// highlighted) content over a red/green/neutral wash.
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.line,
    required this.spans,
    required this.styles,
  });

  /// Horizontal space besides the line text: padding, two gutters, marker.
  static const double chromeWidth = MqSpacing.sm * 2 + 32 + 32 + 14;

  final DiffLine line;
  final List<WordSpan>? spans;
  final _DiffStyles styles;

  @override
  Widget build(BuildContext context) {
    final TextStyle mono = styles.mono;
    final Color rowBg = switch (line.op) {
      DiffOp.delete => styles.deleteBg,
      DiffOp.insert => styles.insertBg,
      DiffOp.equal => const Color(0x00000000),
    };
    final ({String mark, TextStyle style}) marker = switch (line.op) {
      DiffOp.delete => (mark: '-', style: styles.deleteMark),
      DiffOp.insert => (mark: '+', style: styles.insertMark),
      DiffOp.equal => (mark: ' ', style: styles.equalMark),
    };
    final TextStyle highlight = line.op == DiffOp.delete
        ? styles.deleteWord
        : styles.insertWord;

    final Widget content = spans == null
        ? Text(line.text, style: mono, softWrap: false)
        : Text.rich(
            TextSpan(
              children: <InlineSpan>[
                for (final WordSpan s in spans!)
                  TextSpan(
                    text: s.text,
                    style: s.op == DiffOp.equal ? mono : highlight,
                  ),
              ],
            ),
            style: mono,
            softWrap: false,
          );

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.sm,
        vertical: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Gutter(line.aLine, styles.gutter),
          _Gutter(line.bLine, styles.gutter),
          SizedBox(width: 14, child: Text(marker.mark, style: marker.style)),
          // Flexible (not Expanded) keeps the IntrinsicWidth path's sizing;
          // in the measured virtual view a line past the estimate clips.
          Flexible(child: content),
        ],
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter(this.number, this.style);

  final int? number;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }
}
