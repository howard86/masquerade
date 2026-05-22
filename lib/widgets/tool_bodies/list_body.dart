import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../../utils/list_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

enum ListMode { split, join }

class ListToolBody extends StatefulWidget {
  const ListToolBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
    this.link,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  /// Non-null when this card is in a canvas Link group. The group's canonical
  /// value is this tool's raw input text (the lines/text it operates on), so a
  /// list ↔ diff link shares the same source text (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<ListToolBody> createState() => _ListToolBodyState();
}

class _ListToolBodyState extends State<ListToolBody>
    with LinkableToolBody<ListToolBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  ListMode _mode = ListMode.join;
  ListSeparator _separator = ListSeparator.comma;
  ListCase _caseMode = ListCase.none;
  bool _dedupe = false;
  bool _sort = false;
  bool _quote = false;
  QuoteStyle _quoteStyle = QuoteStyle.doubleQuote;
  bool _bracket = false;

  String? _output;
  int _parsedCount = 0;
  int _outCount = 0;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _convert();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
    initLink();
  }

  @override
  void didUpdateWidget(ListToolBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (raw input text canonical) ──────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical is the raw input text — the list is a transform *of* that
  /// text, so the input (not the joined/split output) is the shared value.
  @override
  String currentCanonical() => _controller.text;

  @override
  void applyInbound(String canonical) {
    _controller.text = canonical;
    _convert();
  }

  void _updateActionBar() {
    widget.actionBar?.bind(
      onPaste: _paste,
      onClear: _clear,
      center: MqButton(
        label: 'Swap',
        icon: MqIcons.swap,
        variant: MqButtonVariant.glass,
        onPressed: _output == null ? null : _swap,
        full: true,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'list',
      );
      if (widget.seedSource == SeedSource.paste) {
        _recorder!.markPaste();
      }
    }
  }

  @override
  void dispose() {
    disposeLink();
    _debounce?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _convert);
  }

  void _convert() {
    final String input = _controller.text;
    final List<String> items = ListParser.parse(input);
    if (items.isEmpty) {
      setState(() {
        _output = null;
        _parsedCount = 0;
        _outCount = 0;
      });
      _updateActionBar();
      emitToLink();
      return;
    }
    final List<String> transformed = ListParser.transform(
      items,
      caseMode: _caseMode,
      dedupe: _dedupe,
      sort: _sort,
    );
    final String result = ListParser.join(
      transformed,
      separator: _mode == ListMode.split ? '\n' : _separator.value,
      quote: _quote,
      quoteChar: _quoteStyle.char,
      bracket: _bracket,
    );
    setState(() {
      _output = result;
      _parsedCount = items.length;
      _outCount = transformed.length;
    });
    _recorder?.record(input, result);
    _updateActionBar();
    emitToLink();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _recorder?.markPaste();
    _convert();
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _output = null;
      _parsedCount = 0;
      _outCount = 0;
    });
    _updateActionBar();
  }

  void _swap() {
    final String? out = _output;
    if (out == null) return;
    setState(() {
      _mode = _mode == ListMode.join ? ListMode.split : ListMode.join;
      _controller.text = out;
    });
    _recorder?.markPaste();
    _convert();
  }

  void _cycleCase() {
    setState(() {
      _caseMode = switch (_caseMode) {
        ListCase.none => ListCase.upper,
        ListCase.upper => ListCase.lower,
        ListCase.lower => ListCase.none,
      };
    });
    _convert();
  }

  Future<void> _pickSeparator() async {
    final ListSeparator? choice = await showCupertinoModalPopup<ListSeparator>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Separator'),
        actions: <Widget>[
          for (final ListSeparator s in ListSeparator.values)
            CupertinoActionSheetAction(
              isDefaultAction: s == _separator,
              onPressed: () => Navigator.of(ctx).pop(s),
              child: Text(s.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice != null) {
      setState(() => _separator = choice);
      _convert();
    }
  }

  String get _caseLabel => switch (_caseMode) {
    ListCase.none => 'Case',
    ListCase.upper => 'UPPER',
    ListCase.lower => 'lower',
  };

  String get _countHint {
    if (_dedupe && _outCount != _parsedCount) {
      return '$_parsedCount items · $_outCount after dedupe';
    }
    return '$_parsedCount items';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<ListMode>(
          options: const <ListMode, String>{
            ListMode.split: 'Split',
            ListMode.join: 'Join',
          },
          selected: _mode,
          onChanged: (ListMode m) {
            setState(() => _mode = m);
            _convert();
          },
        ),
        if (_mode == ListMode.join) ...<Widget>[
          const SizedBox(height: MqSpacing.md),
          _SeparatorField(value: _separator.label, onTap: _pickSeparator),
        ],
        const SizedBox(height: MqSpacing.md),
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: _mode == ListMode.join
              ? 'Paste a list — one item per line or any delimiter'
              : 'Paste a delimited string to split into lines',
          onChanged: _onChanged,
          onPaste: (_) => _recorder?.markPaste(),
          multiline: true,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            MqChip(
              label: _caseLabel,
              accent: _caseMode != ListCase.none,
              onTap: _cycleCase,
            ),
            MqChip(
              label: 'Dedupe',
              accent: _dedupe,
              mono: false,
              onTap: () {
                setState(() => _dedupe = !_dedupe);
                _convert();
              },
            ),
            MqChip(
              label: 'Sort A→Z',
              accent: _sort,
              mono: false,
              onTap: () {
                setState(() => _sort = !_sort);
                _convert();
              },
            ),
            MqChip(
              label: 'Quote',
              accent: _quote,
              mono: false,
              onTap: () {
                setState(() => _quote = !_quote);
                _convert();
              },
            ),
            if (_quote)
              MqChip(
                label: _quoteStyle == QuoteStyle.doubleQuote ? '"x"' : "'x'",
                accent: true,
                onTap: () {
                  setState(
                    () => _quoteStyle = _quoteStyle == QuoteStyle.doubleQuote
                        ? QuoteStyle.singleQuote
                        : QuoteStyle.doubleQuote,
                  );
                  _convert();
                },
              ),
            MqChip(
              label: '[ ]',
              accent: _bracket,
              onTap: () {
                setState(() => _bracket = !_bracket);
                _convert();
              },
            ),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_output != null) ...<Widget>[
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: _mode == ListMode.join ? 'Joined' : 'Lines',
            value: _output!,
            hint: _countHint,
            accent: true,
            // Canvas-only: the output is plain text, draggable to a Diff card.
            // Inert on mobile (no PipeScope ancestor).
            pipeType: ContentType.text,
          ),
          OpenInFooter(
            output: _output,
            excludeUtilityId: 'list',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          MqEmptyHint(
            label: _mode == ListMode.join
                ? 'Paste a list to join into one line.'
                : 'Paste a delimited string to split into lines.',
          ),
      ],
    );
  }
}

/// Tappable field showing the active Join separator; opens the picker sheet.
class _SeparatorField extends StatelessWidget {
  const _SeparatorField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MqSurface(
        radius: MqRadius.sm,
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Text(
              'Separator',
              style: MqTextStyles.subhead.copyWith(color: c.textSec),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MqTextStyles.subhead.copyWith(color: c.textPri),
              ),
            ),
            const SizedBox(width: 4),
            Icon(MqIcons.chevD, size: 16, color: c.textTer),
          ],
        ),
      ),
    );
  }
}
