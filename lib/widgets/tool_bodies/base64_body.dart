import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../utility_catalog.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_chip.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/tool_action_bar.dart';
import 'linkable_body.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';

enum Base64Mode { encode, decode }

class Base64Body extends StatefulWidget {
  const Base64Body({
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
  /// value is the plain text; this body projects it to base64 and parses
  /// base64 edits back to text (see docs/adr/0001).
  final LinkChannel? link;

  @override
  State<Base64Body> createState() => _Base64BodyState();
}

class _Base64BodyState extends State<Base64Body>
    with LinkableToolBody<Base64Body> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  Base64Mode _mode = Base64Mode.encode;
  bool _urlSafe = false;
  bool _stripPadding = false;
  String? _output;
  String? _error;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      // Hero detector only suggests Base64 for encoded-looking inputs, so
      // a seed always enters Decode mode.
      _mode = Base64Mode.decode;
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
  void didUpdateWidget(Base64Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateLink();
  }

  // ─── Canonical-hub link (plain-text canonical) ──────────────────────────
  @override
  LinkChannel? get linkChannel => widget.link;

  /// The canonical (plain text) is the input in Encode mode and the decoded
  /// output in Decode mode.
  @override
  String currentCanonical() =>
      _mode == Base64Mode.encode ? _controller.text : (_output ?? '');

  @override
  void applyInbound(String canonical) {
    // Drive the editable field so a re-[_convert] reproduces [canonical]:
    // Encode mode edits plain text directly; Decode mode edits base64.
    _controller.text = _mode == Base64Mode.encode
        ? canonical
        : _encodeForDisplay(canonical);
    _convert();
  }

  /// Encodes [text] the way the current chips dictate, so the value shown in
  /// the Decode input round-trips back to [text] through [_convert].
  String _encodeForDisplay(String text) {
    final List<int> bytes = utf8.encode(text);
    String s = _urlSafe ? base64UrlEncode(bytes) : base64Encode(bytes);
    if (_stripPadding) s = s.replaceAll('=', '');
    return s;
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
        utilityId: 'base64',
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
    if (input.isEmpty) {
      setState(() {
        _output = null;
        _error = null;
      });
      _updateActionBar();
      emitToLink();
      return;
    }
    try {
      String result;
      if (_mode == Base64Mode.encode) {
        final List<int> bytes = utf8.encode(input);
        result = _urlSafe ? base64UrlEncode(bytes) : base64Encode(bytes);
        if (_stripPadding) result = result.replaceAll('=', '');
      } else {
        String src = input.trim();
        if (_stripPadding && src.length % 4 != 0) {
          src = src.padRight(src.length + (4 - src.length % 4), '=');
        }
        final Codec<List<int>, String> codec = _urlSafe ? base64Url : base64;
        final List<int> bytes = codec.decode(src);
        result = utf8.decode(bytes, allowMalformed: true);
      }
      setState(() {
        _output = result;
        _error = null;
      });
      _recorder?.record(input, result);
      emitToLink();
    } on FormatException catch (e) {
      setState(() {
        _output = null;
        _error = 'Invalid base64: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _output = null;
        _error = 'Conversion failed: $e';
      });
    }
    _updateActionBar();
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
      _error = null;
    });
    _updateActionBar();
  }

  void _swap() {
    final String? out = _output;
    if (out == null) return;
    setState(() {
      _mode = _mode == Base64Mode.encode
          ? Base64Mode.decode
          : Base64Mode.encode;
      _controller.text = out;
    });
    _recorder?.markPaste();
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<Base64Mode>(
          options: const <Base64Mode, String>{
            Base64Mode.encode: 'Encode',
            Base64Mode.decode: 'Decode',
          },
          selected: _mode,
          onChanged: (Base64Mode m) {
            setState(() => _mode = m);
            _convert();
          },
        ),
        const SizedBox(height: MqSpacing.md),
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: _mode == Base64Mode.encode
              ? 'Plain text'
              : 'Encoded string',
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
              label: 'URL-safe',
              accent: _urlSafe,
              mono: false,
              onTap: () {
                setState(() => _urlSafe = !_urlSafe);
                _convert();
              },
            ),
            MqChip(
              label: 'Strip padding',
              accent: _stripPadding,
              mono: false,
              onTap: () {
                setState(() => _stripPadding = !_stripPadding);
                _convert();
              },
            ),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        if (_error != null)
          MqMonoCell(label: 'Error', value: _error!, copyable: false)
        else if (_output != null) ...<Widget>[
          const MqSectionHeader(label: 'Output'),
          MqMonoCell(
            label: _mode == Base64Mode.encode ? 'Base64' : 'Plain text',
            value: _output!,
            accent: true,
          ),
          OpenInFooter(
            output: _output,
            excludeUtilityId: 'base64',
            onSwitchTool: widget.onSwitchTool,
          ),
        ] else
          MqEmptyHint(
            label: _mode == Base64Mode.encode
                ? 'Paste plain text to encode.'
                : 'Paste a Base64 string to decode.',
          ),
      ],
    );
  }
}
