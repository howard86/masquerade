import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

/// Masquerade underline-only text input. No fill — the bottom rule carries
/// state (resting border, focused accent, error danger).
class MqInput extends StatefulWidget {
  const MqInput({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.mono = true,
    this.multiline = false,
    this.error,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onPaste,
    this.autofocus = false,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.semanticsLabel,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final bool mono;
  final bool multiline;
  final String? error;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  /// Fires when the controller's text grew by ≥4 characters in one tick.
  final ValueChanged<String>? onPaste;

  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? semanticsLabel;

  /// Optional externally-owned focus node. When omitted, MqInput owns one
  /// internally and disposes it. When provided, the caller owns disposal.
  final FocusNode? focusNode;

  @override
  State<MqInput> createState() => _MqInputState();
}

class _MqInputState extends State<MqInput> {
  late final FocusNode _focus;
  late final bool _ownsFocus;
  bool _focused = false;
  String _prevText = '';

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _prevText = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(MqInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _prevText = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final String newText = widget.controller.text;
    if (newText == _prevText) return;
    final int delta = newText.length - _prevText.length;
    _prevText = newText;
    final ValueChanged<String>? onPaste = widget.onPaste;
    if (onPaste != null && delta >= 4) {
      onPaste(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;
    final hasError = widget.error != null;

    final TextStyle textStyle =
        (widget.mono ? MqTextStyles.monoMd : MqTextStyles.body).copyWith(
          color: c.textPri,
        );
    final TextStyle placeholderStyle = textStyle.copyWith(color: c.textTer);

    final Color underlineColor = hasError
        ? c.danger
        : _focused
        ? c.accent
        : c.border;
    final double underlineWidth = hasError || _focused ? 1.5 : 0.5;

    final BoxDecoration decoration = BoxDecoration(
      border: Border(
        bottom: BorderSide(color: underlineColor, width: underlineWidth),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
            child: Text(
              widget.label!.toUpperCase(),
              style: MqTextStyles.sectionLabel.copyWith(color: c.textSec),
            ),
          ),
        Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: MqSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: widget.multiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.leading != null) ...<Widget>[
                widget.leading!,
                const SizedBox(width: MqSpacing.sm),
              ],
              Expanded(
                child: Semantics(
                  label: widget.semanticsLabel ?? widget.label,
                  child: CupertinoTextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    placeholder: widget.placeholder,
                    placeholderStyle: placeholderStyle,
                    style: textStyle,
                    cursorColor: c.accent,
                    decoration: const BoxDecoration(),
                    padding: EdgeInsets.zero,
                    onChanged: widget.onChanged,
                    autofocus: widget.autofocus,
                    minLines: widget.multiline ? (widget.minLines ?? 4) : 1,
                    maxLines: widget.multiline ? (widget.maxLines ?? 8) : 1,
                    keyboardType:
                        widget.keyboardType ??
                        (widget.multiline
                            ? TextInputType.multiline
                            : TextInputType.text),
                  ),
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: MqSpacing.sm),
                widget.trailing!,
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: Row(
              children: <Widget>[
                Icon(MqIcons.warn, size: 13, color: c.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.error!,
                    style: MqTextStyles.footnote.copyWith(color: c.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
