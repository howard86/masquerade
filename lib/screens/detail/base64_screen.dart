import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../widgets/mq/mq_button.dart';
import '../../widgets/mq/mq_chip.dart';
import '../../widgets/mq/mq_icons.dart';
import '../../widgets/mq/mq_input.dart';
import '../../widgets/mq/mq_mono_cell.dart';
import '../../widgets/mq/mq_section_header.dart';
import '../../widgets/mq/mq_segmented.dart';
import 'detail_scaffold.dart';

enum Base64Mode { encode, decode }

class Base64Screen extends StatefulWidget {
  const Base64Screen({super.key, this.initialInput});

  final String? initialInput;

  @override
  State<Base64Screen> createState() => _Base64ScreenState();
}

class _Base64ScreenState extends State<Base64Screen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  Base64Mode _mode = Base64Mode.encode;
  bool _urlSafe = false;
  bool _stripPadding = false;
  String? _output;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      // Seed enters Decode mode since hero detector only suggests Base64 for
      // encoded-looking inputs.
      _mode = Base64Mode.decode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _convert();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
      HistoryScope.of(context).add(
        HistoryEntry(
          utilityId: 'base64',
          input: input,
          output: result,
          timestamp: DateTime.now(),
        ),
      );
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
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _convert();
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _output = null;
      _error = null;
    });
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
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return MqDetailScaffold(
      title: 'Base64',
      subtitle: 'Encode/decode. Swap. URL-safe + strip-padding options.',
      bottomBar: Row(
        children: <Widget>[
          Expanded(
            child: MqButton(
              label: 'Paste',
              icon: MqIcons.paste,
              variant: MqButtonVariant.glass,
              onPressed: _paste,
              full: true,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: MqButton(
              label: 'Swap',
              icon: MqIcons.swap,
              variant: MqButtonVariant.glass,
              onPressed: _output == null ? null : _swap,
              full: true,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: MqButton(
              label: 'Clear',
              icon: MqIcons.clear,
              variant: MqButtonVariant.glass,
              onPressed: _clear,
              full: true,
            ),
          ),
        ],
      ),
      child: Column(
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
            multiline: true,
            minLines: 3,
            maxLines: 8,
          ),
          const SizedBox(height: MqSpacing.md),
          Row(
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
              const SizedBox(width: MqSpacing.sm),
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
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
              child: Text(
                _mode == Base64Mode.encode
                    ? 'Paste plain text to encode.'
                    : 'Paste a Base64 string to decode.',
                style: MqTextStyles.subhead.copyWith(color: c.textTer),
              ),
            ),
        ],
      ),
    );
  }
}
