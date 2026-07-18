import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/history_recorder.dart';
import '../../utils/regex_parser.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_status.dart';
import '../mq/mq_surface.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

class RegexBody extends StatefulWidget {
  const RegexBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.actionBar,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final ToolActionBarController? actionBar;

  @override
  State<RegexBody> createState() => _RegexBodyState();
}

class _RegexBodyState extends State<RegexBody> {
  static const int _pageSize = 20;

  final TextEditingController _pattern = TextEditingController();
  final TextEditingController _input = TextEditingController();
  Timer? _debounce;
  HistoryRecorder? _recorder;
  RegexResult? _result;
  bool _caseSensitive = true;
  bool _multiLine = false;
  bool _dotAll = false;
  bool _unicode = true;
  bool _settingsRestored = false;
  int _visibleMatches = _pageSize;

  @override
  void initState() {
    super.initState();
    _input.text = widget.initialInput ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run();
      _bindActionBar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'regex',
        sensitive:
            MobileSessionRouteScope.maybeOf(context)?.protectedSession ?? false,
      );
      if (widget.seedSource == SeedSource.paste) _recorder!.markPaste();
    }
    if (_settingsRestored) return;
    _settingsRestored = true;
    final Map<String, Object?> settings =
        MobileSessionRouteScope.maybeOf(context)?.settings ??
        const <String, Object?>{};
    if (settings['pattern'] case final String pattern) _pattern.text = pattern;
    _caseSensitive = settings['caseSensitive'] is bool
        ? settings['caseSensitive']! as bool
        : _caseSensitive;
    _multiLine = settings['multiLine'] is bool
        ? settings['multiLine']! as bool
        : _multiLine;
    _dotAll = settings['dotAll'] is bool
        ? settings['dotAll']! as bool
        : _dotAll;
    _unicode = settings['unicode'] is bool
        ? settings['unicode']! as bool
        : _unicode;
  }

  @override
  void didUpdateWidget(RegexBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionBar != oldWidget.actionBar) _bindActionBar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    _pattern.dispose();
    _input.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _saveSettings();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _run);
  }

  void _toggle(void Function() change) {
    setState(change);
    _saveSettings();
    _run();
  }

  void _run() {
    if (!mounted) return;
    final RegexResult? result = _pattern.text.isEmpty && _input.text.isEmpty
        ? null
        : RegexTester.run(
            pattern: _pattern.text,
            input: _input.text,
            caseSensitive: _caseSensitive,
            multiLine: _multiLine,
            dotAll: _dotAll,
            unicode: _unicode,
          );
    setState(() {
      _result = result;
      _visibleMatches = _pageSize;
    });
    if (result case final RegexOk ok
        when _pattern.text.isNotEmpty && _input.text.isNotEmpty) {
      _recorder?.record(
        _input.text,
        ok.matches
            .take(20)
            .map((RegexMatchInfo match) => match.text)
            .join('\n'),
      );
    }
  }

  void _saveSettings() => MobileSessionRouteScope.maybeOf(context)
      ?.onSettingsChanged
      ?.call(<String, Object?>{
        'pattern': _pattern.text,
        'caseSensitive': _caseSensitive,
        'multiLine': _multiLine,
        'dotAll': _dotAll,
        'unicode': _unicode,
      });

  void _clear() {
    _debounce?.cancel();
    _pattern.clear();
    _input.clear();
    setState(() {
      _result = null;
      _visibleMatches = _pageSize;
    });
    _saveSettings();
    _bindActionBar();
  }

  void _bindActionBar() => widget.actionBar?.bind(onClear: _clear);

  @override
  Widget build(BuildContext context) {
    final RegexResult? result = _result;
    final RegexOk? ok = result is RegexOk ? result : null;
    final List<RegexMatchInfo> visible =
        ok?.matches.take(_visibleMatches).toList(growable: false) ??
        const <RegexMatchInfo>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqInput(
          key: const ValueKey<String>('regex-pattern'),
          controller: _pattern,
          label: 'Pattern',
          placeholder: r'(?<year>\d{4})',
          onChanged: _changed,
          onPaste: (_) => _recorder?.markPaste(),
          error: result is RegexErr ? result.message : null,
          semanticsLabel: 'Regular expression pattern',
        ),
        const SizedBox(height: MqSpacing.md),
        MqInput(
          key: const ValueKey<String>('regex-input'),
          controller: _input,
          label: 'Test string',
          placeholder: 'Paste text to test…',
          multiline: true,
          minLines: 4,
          maxLines: 10,
          onChanged: _changed,
          onPaste: (_) => _recorder?.markPaste(),
          semanticsLabel: 'Regular expression test string',
        ),
        const SizedBox(height: MqSpacing.md),
        Wrap(
          spacing: MqSpacing.sm,
          runSpacing: MqSpacing.sm,
          children: <Widget>[
            _flag(
              'Case-sensitive',
              _caseSensitive,
              () => _toggle(() => _caseSensitive = !_caseSensitive),
            ),
            _flag(
              'Multi-line',
              _multiLine,
              () => _toggle(() => _multiLine = !_multiLine),
            ),
            _flag('Dot-all', _dotAll, () => _toggle(() => _dotAll = !_dotAll)),
            _flag(
              'Unicode',
              _unicode,
              () => _toggle(() => _unicode = !_unicode),
            ),
          ],
        ),
        const SizedBox(height: MqSpacing.md),
        const MqStatus(
          label:
              'Runs locally. Complex backtracking patterns can still make matching slow.',
          kind: MqStatusKind.info,
        ),
        const SizedBox(height: MqSpacing.lg),
        if (result == null)
          const MqEmptyHint(label: 'Enter a pattern or test string.')
        else if (result is RegexErr)
          const SizedBox.shrink()
        else ...<Widget>[
          const _RegexHeader('Highlighted input'),
          _Highlight(input: _input.text, matches: ok!.matches),
          const SizedBox(height: MqSpacing.lg),
          const _RegexHeader('Matches'),
          if (ok.truncated)
            const Padding(
              padding: EdgeInsets.only(bottom: MqSpacing.sm),
              child: MqStatus(
                label: 'Showing the first 10,000 matches.',
                kind: MqStatusKind.warning,
              ),
            ),
          if (ok.matches.isEmpty)
            const MqEmptyHint(label: 'No matches.')
          else ...<Widget>[
            MqStatus(
              label:
                  'Showing ${visible.length} of ${ok.matches.length} matches',
              kind: MqStatusKind.neutral,
            ),
            const SizedBox(height: MqSpacing.sm),
            for (final (int index, RegexMatchInfo match)
                in visible.indexed) ...<Widget>[
              _MatchCard(index: index, match: match),
              const SizedBox(height: MqSpacing.sm),
            ],
            if (visible.length < ok.matches.length)
              Align(
                alignment: Alignment.centerLeft,
                child: MqButton(
                  label: 'Show 20 more',
                  variant: MqButtonVariant.glass,
                  onPressed: () => setState(() => _visibleMatches += _pageSize),
                ),
              ),
          ],
        ],
      ],
    );
  }

  MqChip _flag(String label, bool selected, VoidCallback onTap) =>
      MqChip(label: label, mono: false, selected: selected, onTap: onTap);
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.input, required this.matches});

  static const int _maxHighlights = 2000;

  final String input;
  final List<RegexMatchInfo> matches;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final TextStyle normal = MqTextStyles.monoSm.copyWith(color: c.monoText);
    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    int highlighted = 0;
    for (final RegexMatchInfo match in matches) {
      if (match.start == match.end) continue;
      if (highlighted == _maxHighlights) break;
      int start = match.start;
      int end = match.end;
      if (start > 0 && _isLow(input.codeUnitAt(start))) start--;
      if (end < input.length && _isHigh(input.codeUnitAt(end - 1))) end++;
      if (end <= cursor) continue;
      if (start < cursor) start = cursor;
      if (start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: input.substring(start, end),
          style: normal.copyWith(
            color: c.onTint,
            backgroundColor: c.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = end;
      highlighted++;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    final bool bounded = matches
        .where((RegexMatchInfo match) => match.start != match.end)
        .skip(_maxHighlights)
        .isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSurface(
          background: c.monoBg,
          child: RichText(
            key: const ValueKey<String>('regex-highlight'),
            text: TextSpan(style: normal, children: spans),
          ),
        ),
        if (bounded) ...<Widget>[
          const SizedBox(height: MqSpacing.sm),
          const MqStatus(
            label: 'Highlighting is limited to the first 2,000 matches.',
            kind: MqStatusKind.info,
          ),
        ],
      ],
    );
  }

  static bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}

class _MatchCard extends StatefulWidget {
  const _MatchCard({required this.index, required this.match});

  final int index;
  final RegexMatchInfo match;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  static const int _pageSize = 20;
  static const int _previewLength = 1000;
  int _visibleCaptures = _pageSize;

  @override
  void didUpdateWidget(_MatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.match, widget.match)) {
      _visibleCaptures = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final RegexMatchInfo match = widget.match;
    final List<({String label, String? value})> captures =
        <({String label, String? value})>[
          for (final (int index, String? value) in match.groups.indexed)
            (label: '\$${index + 1}', value: value),
          for (final MapEntry<String, String?> entry in match.named.entries)
            (label: entry.key, value: entry.value),
        ];
    final List<({String label, String? value})> visible = captures
        .take(_visibleCaptures)
        .toList(growable: false);
    return MqSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RegexHeader(
            'Match ${widget.index + 1} · ${match.start}..${match.end}',
          ),
          MqMonoCell(
            label: 'Full match',
            value: _display(match.text),
            copyValue: match.text,
            copyable: match.text.isNotEmpty,
          ),
          for (final ({String label, String? value}) capture
              in visible) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            MqMonoCell(
              label: capture.label,
              value: capture.value == null
                  ? 'Not matched'
                  : _display(capture.value!),
              copyValue: capture.value,
              copyable: capture.value?.isNotEmpty == true,
            ),
          ],
          if (visible.length < captures.length) ...<Widget>[
            const SizedBox(height: MqSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'Show 20 more captures',
                variant: MqButtonVariant.glass,
                onPressed: () => setState(() => _visibleCaptures += _pageSize),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _display(String value) {
    if (value.isEmpty) return 'Empty match';
    int end = value.length.clamp(0, _previewLength);
    if (end < value.length) {
      final int last = value.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
    }
    final String source = value.substring(0, end);
    final StringBuffer safe = StringBuffer();
    for (int index = 0; index < source.length; index++) {
      final int unit = source.codeUnitAt(index);
      if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < source.length) {
        final int next = source.codeUnitAt(index + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          safe.write(source.substring(index, index + 2));
          index++;
          continue;
        }
      }
      if (unit >= 0xD800 && unit <= 0xDFFF) {
        safe.write(r'\u');
        safe.write(unit.toRadixString(16).toUpperCase().padLeft(4, '0'));
      } else {
        safe.writeCharCode(unit);
      }
    }
    if (end < value.length) safe.write('…');
    return safe.toString();
  }
}

class _RegexHeader extends StatelessWidget {
  const _RegexHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
    child: Text(
      label.toUpperCase(),
      softWrap: true,
      style: MqTextStyles.sectionLabel.copyWith(
        color: context.mq.colors.textSec,
      ),
    ),
  );
}
