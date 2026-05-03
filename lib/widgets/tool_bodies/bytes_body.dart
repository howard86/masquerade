import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../utils/bytes_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import 'seed_source.dart';

enum BytesMode { encode, decode }

class BytesBody extends StatefulWidget {
  const BytesBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
  });

  final String? initialInput;
  final SeedSource seedSource;

  @override
  State<BytesBody> createState() => _BytesBodyState();
}

class _BytesBodyState extends State<BytesBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BytesMode _mode = BytesMode.decode;
  String? _outSpace;
  String? _outBrackets;
  String? _outHex;
  String? _decodedText;
  String? _decodedHex;
  String? _error;

  late final HistoryRecorder _recorder;
  bool _recorderInited = false;
  bool _nextWriteIsPaste = false;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      _mode = BytesMode.decode;
      _nextWriteIsPaste = widget.seedSource == SeedSource.paste;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _convert();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recorderInited) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: 'bytes',
      );
      _recorderInited = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_recorderInited) _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _convert);
  }

  void _resetOutputs() {
    _outSpace = null;
    _outBrackets = null;
    _outHex = null;
    _decodedText = null;
    _decodedHex = null;
    _error = null;
  }

  void _convert() {
    final String input = _controller.text;
    if (input.isEmpty) {
      setState(_resetOutputs);
      return;
    }

    if (_mode == BytesMode.encode) {
      final Uint8List bytes = BytesParser.encodeUtf8(input);
      setState(() {
        _resetOutputs();
        _outSpace = BytesParser.format(bytes, BytesFormat.space);
        _outBrackets = BytesParser.format(bytes, BytesFormat.brackets);
        _outHex = BytesParser.format(bytes, BytesFormat.hex);
      });
      _record(input, _outSpace!);
      return;
    }

    switch (BytesParser.parse(input)) {
      case BytesParseError(:final message):
        setState(() {
          _resetOutputs();
          _error = message;
        });
      case BytesParseOk(:final bytes):
        final String hex = BytesParser.format(bytes, BytesFormat.hex);
        String? text;
        String? error;
        try {
          text = utf8.decode(bytes);
        } on FormatException catch (e) {
          error = 'Invalid UTF-8: ${e.message}';
        }
        setState(() {
          _resetOutputs();
          _decodedText = text;
          _decodedHex = hex;
          _error = error;
        });
        _record(input, text ?? hex);
    }
  }

  void _record(String input, String output) {
    if (_nextWriteIsPaste) {
      _recorder.recordPaste(input, output);
      _nextWriteIsPaste = false;
    } else {
      _recorder.recordTyping(input, output);
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _controller.text = data!.text!;
    _nextWriteIsPaste = true;
    _convert();
  }

  void _clear() {
    _controller.clear();
    setState(_resetOutputs);
  }

  String? get _swapPayload => switch (_mode) {
    BytesMode.encode => _outSpace,
    BytesMode.decode => _decodedText,
  };

  void _swap() {
    final String? payload = _swapPayload;
    if (payload == null) return;
    setState(() {
      _mode = _mode == BytesMode.encode ? BytesMode.decode : BytesMode.encode;
      _controller.text = payload;
    });
    _nextWriteIsPaste = true;
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MqSegmented<BytesMode>(
          options: const <BytesMode, String>{
            BytesMode.encode: 'Encode',
            BytesMode.decode: 'Decode',
          },
          selected: _mode,
          onChanged: (BytesMode m) {
            setState(() => _mode = m);
            _convert();
          },
        ),
        const SizedBox(height: MqSpacing.md),
        MqInput(
          controller: _controller,
          label: 'Input',
          placeholder: _mode == BytesMode.encode
              ? 'Plain text'
              : '[72, 101, 108, 108, 111] or 72 101 108 108 111',
          onChanged: _onChanged,
          multiline: true,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: MqSpacing.lg),
        ..._buildOutput(),
        const SizedBox(height: MqSpacing.lg),
        Row(
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
                onPressed: _swapPayload == null ? null : _swap,
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
      ],
    );
  }

  List<Widget> _buildOutput() {
    if (_mode == BytesMode.encode) {
      if (_outSpace == null) {
        return const <Widget>[
          MqEmptyHint(label: 'Type text to encode as bytes.'),
        ];
      }
      return <Widget>[
        const MqSectionHeader(label: 'Output'),
        MqMonoCell(label: 'Space', value: _outSpace!, accent: true),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'Brackets', value: _outBrackets!),
        const SizedBox(height: MqSpacing.sm),
        MqMonoCell(label: 'Hex', value: _outHex!),
      ];
    }
    if (_decodedHex == null) {
      if (_error != null) {
        return <Widget>[
          MqMonoCell(label: 'Error', value: _error!, copyable: false),
        ];
      }
      return const <Widget>[
        MqEmptyHint(label: 'Paste integers (0–255) to decode as UTF-8.'),
      ];
    }
    return <Widget>[
      const MqSectionHeader(label: 'Output'),
      MqMonoCell(
        label: 'Text (UTF-8)',
        value: _decodedText ?? _error ?? 'Invalid UTF-8',
        accent: _decodedText != null,
        copyable: _decodedText != null,
      ),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Hex', value: _decodedHex!),
    ];
  }
}
