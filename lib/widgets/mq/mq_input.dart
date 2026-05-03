import 'package:flutter/cupertino.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

/// Masquerade recessed-well text input.
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

  /// Fires after a likely paste event — defined as a single onChanged tick
  /// whose text grew by ≥ 4 characters. Catches system Paste menu, ⌘V, the
  /// iOS magnifying-glass paste, and multi-word dictation commits without
  /// intercepting [PasteTextIntent] (which routes inconsistently between
  /// the magnifier menu and ⌘V on Cupertino 3.41.8).
  ///
  /// The heuristic leans toward false positives (dictation, fast typers,
  /// autocomplete completions) — those still record history immediately
  /// instead of waiting for the typing-debounce window, which is a benign
  /// UX trade-off versus the alternative of a clipboard read on every
  /// keystroke (and the iOS "Pasted from app" banner that triggers).
  final ValueChanged<String>? onPaste;

  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? semanticsLabel;

  @override
  State<MqInput> createState() => _MqInputState();
}

class _MqInputState extends State<MqInput> {
  late final FocusNode _focus = FocusNode();
  bool _focused = false;
  String _prevText = '';

  @override
  void initState() {
    super.initState();
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
    _focus.dispose();
    super.dispose();
  }

  // Fires for both user keystrokes and programmatic controller mutations,
  // so tests that swap text via `tester.enterText` or via setting
  // `controller.text` directly both reach the paste-detection path.
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

    final BoxDecoration decoration = BoxDecoration(
      color: c.surface2,
      borderRadius: BorderRadius.circular(MqRadius.md - 2),
      border: Border.all(
        color: hasError
            ? c.danger
            : _focused
            ? c.accent
            : c.border,
        width: hasError || _focused ? 1.5 : 0.5,
      ),
      boxShadow: _focused && !hasError
          ? <BoxShadow>[
              BoxShadow(
                color: c.accent.withValues(alpha: 0.13),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ]
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              widget.label!.toUpperCase(),
              style: MqTextStyles.sectionLabel.copyWith(color: c.textSec),
            ),
          ),
        Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.md,
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
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
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
