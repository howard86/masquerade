import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/bytes_parser.dart';
import '../../utils/history_recorder.dart';
import '../mq/mq_button.dart';
import '../mq/mq_empty_hint.dart';
import '../mq/mq_icons.dart';
import '../mq/mq_input.dart';
import '../mq/mq_mono_cell.dart';
import '../mq/mq_section_header.dart';
import '../mq/mq_segmented.dart';
import '../mq/tool_action_bar.dart';
import 'open_in_footer.dart';
import 'seed_source.dart';
import 'tool_layout.dart';

enum BytesMode { encode, decode }

/// Decode text encodings offered on the canvas (wide) layout. UTF-8 is the
/// default and the only one a phone sees — the others are dep-free additions
/// (latin1 ships in dart:convert; UTF-16LE is decoded by hand).
enum BytesEncoding { utf8, latin1, utf16le }

class BytesBody extends StatefulWidget {
  const BytesBody({
    super.key,
    this.initialInput,
    this.seedSource = SeedSource.none,
    this.onSwitchTool,
    this.actionBar,
  });

  final String? initialInput;
  final SeedSource seedSource;
  final OpenInToolCallback? onSwitchTool;
  final ToolActionBarController? actionBar;

  @override
  State<BytesBody> createState() => _BytesBodyState();
}

class _BytesBodyState extends State<BytesBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BytesMode _mode = BytesMode.decode;
  BytesEncoding _encoding = BytesEncoding.utf8;
  String? _outSpace;
  String? _outBrackets;
  String? _outHex;
  String? _decodedText;
  String? _decodedHex;
  String? _error;

  /// Bytes from the last successful decode parse — kept so the wide layout can
  /// re-decode under a different [BytesEncoding] and render a hexdump without
  /// re-parsing the input. Null in encode mode or after a parse error.
  Uint8List? _decodedBytes;

  HistoryRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.initialInput;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      _mode = BytesMode.decode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _convert();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActionBar();
    });
  }

  void _updateActionBar() {
    widget.actionBar?.bind(
      onPaste: _paste,
      onClear: _clear,
      center: MqButton(
        label: 'Swap',
        icon: MqIcons.swap,
        variant: MqButtonVariant.glass,
        onPressed: _swapPayload == null ? null : _swap,
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
        utilityId: 'bytes',
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
    _decodedBytes = null;
    _error = null;
  }

  void _convert() {
    final String input = _controller.text;
    if (input.isEmpty) {
      setState(_resetOutputs);
      _updateActionBar();
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
      _recorder?.record(input, _outSpace!);
      _updateActionBar();
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
        final ({String? text, String? error}) decoded = _decode(bytes);
        setState(() {
          _resetOutputs();
          _decodedBytes = bytes;
          _decodedText = decoded.text;
          _decodedHex = hex;
          _error = decoded.error;
        });
        _recorder?.record(input, decoded.text ?? hex);
    }
    _updateActionBar();
  }

  /// Decodes [bytes] under the currently-selected [_encoding]. UTF-8 is the
  /// phone default; Latin-1 and UTF-16LE are exposed only in the wide layout.
  ({String? text, String? error}) _decode(Uint8List bytes) {
    switch (_encoding) {
      case BytesEncoding.utf8:
        try {
          return (text: utf8.decode(bytes), error: null);
        } on FormatException catch (e) {
          return (text: null, error: 'Invalid UTF-8: ${e.message}');
        }
      case BytesEncoding.latin1:
        // Latin-1 maps every byte 1:1 to U+0000..U+00FF, so allowInvalid never
        // actually trips — it just guarantees a non-throwing decode.
        return (text: latin1.decode(bytes, allowInvalid: true), error: null);
      case BytesEncoding.utf16le:
        if (bytes.length.isOdd) {
          return (text: null, error: 'UTF-16LE needs an even byte count.');
        }
        final List<int> units = <int>[
          for (int i = 0; i < bytes.length; i += 2)
            bytes[i] | (bytes[i + 1] << 8),
        ];
        return (text: String.fromCharCodes(units), error: null);
    }
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
    setState(_resetOutputs);
    _updateActionBar();
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
    _recorder?.markPaste();
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kToolCanvasWide;
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
                  : '72 101 108 108 111',
              onChanged: _onChanged,
              onPaste: (_) => _recorder?.markPaste(),
              multiline: true,
              minLines: 3,
              maxLines: 8,
            ),
            // Canvas-only: pick the decode encoding. Hidden on phones (width <
            // [kToolCanvasWide]) where UTF-8 stays the only decode, as today.
            if (wide && _mode == BytesMode.decode) ...<Widget>[
              const SizedBox(height: MqSpacing.md),
              MqSegmented<BytesEncoding>(
                options: const <BytesEncoding, String>{
                  BytesEncoding.utf8: 'UTF-8',
                  BytesEncoding.latin1: 'Latin-1',
                  BytesEncoding.utf16le: 'UTF-16LE',
                },
                selected: _encoding,
                onChanged: (BytesEncoding e) {
                  setState(() => _encoding = e);
                  _convert();
                },
              ),
            ],
            const SizedBox(height: MqSpacing.lg),
            ..._buildOutput(wide),
          ],
        );
      },
    );
  }

  List<Widget> _buildOutput(bool wide) {
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
        OpenInFooter(
          output: _outSpace,
          excludeUtilityId: 'bytes',
          onSwitchTool: widget.onSwitchTool,
        ),
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
        label: 'Text (${_encodingLabel(_encoding)})',
        value: _decodedText ?? _error ?? 'Invalid UTF-8',
        accent: _decodedText != null,
        copyable: _decodedText != null,
      ),
      const SizedBox(height: MqSpacing.sm),
      MqMonoCell(label: 'Hex', value: _decodedHex!),
      // Canvas-only: a classic offset/hex/ASCII hexdump of the parsed bytes.
      if (wide && _decodedBytes != null) ...<Widget>[
        const SizedBox(height: MqSpacing.lg),
        const MqSectionHeader(label: 'Hexdump'),
        _Hexdump(bytes: _decodedBytes!),
      ],
      OpenInFooter(
        output: _decodedText,
        excludeUtilityId: 'bytes',
        onSwitchTool: widget.onSwitchTool,
      ),
    ];
  }

  static String _encodingLabel(BytesEncoding e) => switch (e) {
    BytesEncoding.utf8 => 'UTF-8',
    BytesEncoding.latin1 => 'Latin-1',
    BytesEncoding.utf16le => 'UTF-16LE',
  };
}

/// Monospace `offset  hex bytes  |ascii|` hexdump, 16 bytes per row. Scrolls
/// horizontally so a wide row never overflows under large Dynamic Type.
class _Hexdump extends StatelessWidget {
  const _Hexdump({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<int> rows = <int>[for (int i = 0; i < bytes.length; i += 16) i];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.monoBg,
        borderRadius: BorderRadius.circular(MqRadius.sm),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: MqSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int offset in rows)
              Text(
                _row(offset),
                style: MqTextStyles.monoSm.copyWith(color: c.monoText),
              ),
          ],
        ),
      ),
    );
  }

  String _row(int offset) {
    final int end = (offset + 16).clamp(0, bytes.length);
    final StringBuffer hex = StringBuffer();
    final StringBuffer ascii = StringBuffer();
    for (int i = offset; i < offset + 16; i++) {
      if (i < end) {
        hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
        final int b = bytes[i];
        ascii.writeCharCode(
          b >= 0x20 && b < 0x7f ? b : 0x2e,
        ); // '.' for nonprint
      } else {
        hex.write('  ');
      }
      hex.write(i == offset + 7 ? '  ' : ' ');
    }
    final String off = offset.toRadixString(16).padLeft(8, '0');
    return '$off  ${hex.toString().trimRight()}  |$ascii|';
  }
}
