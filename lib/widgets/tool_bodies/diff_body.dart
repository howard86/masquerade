import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../state/history_controller.dart';
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
import 'seed_source.dart';

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
  });

  final String? initialInput;
  final SeedSource seedSource;
  final ToolActionBarController? actionBar;

  @override
  State<DiffBody> createState() => _DiffBodyState();
}

class _DiffBodyState extends State<DiffBody> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'diff',
      );
      if (widget.seedSource == SeedSource.paste) {
        _recorder!.markPaste();
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
    _updateActionBar();
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
    _updateActionBar();
  }

  void _swap() {
    final String aText = _a.text;
    _a.text = _b.text;
    _b.text = aText;
    _recorder?.markPaste();
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    final DiffResult? result = _result;
    final bool bothEmpty = _a.text.isEmpty && _b.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          controller: _a,
          focusNode: _aFocus,
          label: 'A · original',
          placeholder: 'Paste the original text',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: MqSpacing.md),
        MqInput(
          controller: _b,
          focusNode: _bFocus,
          label: 'B · changed',
          placeholder: 'Paste the changed text',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            MqChip(
              label: 'Word highlight',
              mono: false,
              accent: _wordHighlight,
              onTap: () {
                _wordHighlight = !_wordHighlight;
                _convert();
              },
            ),
            MqChip(
              label: 'Ignore whitespace',
              mono: false,
              accent: _ignoreWhitespace,
              onTap: () {
                _ignoreWhitespace = !_ignoreWhitespace;
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

  Widget _buildDiffView(List<DiffLine> lines) {
    final List<Widget> rows = <Widget>[];
    int cursor = 0;
    for (final DiffHunk h in _hunks) {
      _emitGap(rows, lines, cursor, h.startIndex);
      for (int idx = h.startIndex; idx < h.endIndex; idx++) {
        rows.add(_DiffRow(line: lines[idx], spans: _spans[idx]));
      }
      cursor = h.endIndex;
    }
    _emitGap(rows, lines, cursor, lines.length);

    return MqSurface(
      padded: false,
      background: context.mq.colors.monoBg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MqRadius.md),
        // Lines stay single-line and the body scrolls horizontally so the
        // old/new gutters stay column-aligned. IntrinsicWidth sizes every row
        // to the widest line so the red/green washes span the full scrolled
        // width rather than stopping at the viewport edge.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  void _emitGap(List<Widget> rows, List<DiffLine> lines, int from, int to) {
    if (to <= from) return;
    if (_expanded.contains(from)) {
      for (int idx = from; idx < to; idx++) {
        rows.add(_DiffRow(line: lines[idx], spans: null));
      }
    } else {
      rows.add(
        _CollapseDivider(
          count: to - from,
          onTap: () => setState(() => _expanded.add(from)),
        ),
      );
    }
  }
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
              '$count unchanged ${count == 1 ? 'line' : 'lines'}',
              style: MqTextStyles.caption1.copyWith(color: c.textTer),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rendered diff line: old/new gutters, marker, and (optionally word-level
/// highlighted) content over a red/green/neutral wash.
class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.line, required this.spans});

  final DiffLine line;
  final List<WordSpan>? spans;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final TextStyle mono = MqTextStyles.monoSm.copyWith(color: c.monoText);

    final Color rowBg = switch (line.op) {
      DiffOp.delete => c.dangerBg,
      DiffOp.insert => c.successBg,
      DiffOp.equal => const Color(0x00000000),
    };
    final ({String mark, Color color}) marker = switch (line.op) {
      DiffOp.delete => (mark: '-', color: c.danger),
      DiffOp.insert => (mark: '+', color: c.success),
      DiffOp.equal => (mark: ' ', color: c.textTer),
    };
    final Color highlight = line.op == DiffOp.delete ? c.danger : c.success;

    final Widget content = spans == null
        ? Text(line.text, style: mono, softWrap: false)
        : Text.rich(
            TextSpan(
              children: <InlineSpan>[
                for (final WordSpan s in spans!)
                  TextSpan(
                    text: s.text,
                    style: s.op == DiffOp.equal
                        ? mono
                        : mono.copyWith(
                            color: c.onTint,
                            backgroundColor: highlight,
                            fontWeight: FontWeight.w600,
                          ),
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
          _Gutter(line.aLine),
          _Gutter(line.bLine),
          SizedBox(
            width: 14,
            child: Text(
              marker.mark,
              style: MqTextStyles.monoSm.copyWith(color: marker.color),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter(this.number);

  final int? number;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: MqTextStyles.monoSm.copyWith(color: context.mq.colors.textTer),
      ),
    );
  }
}
