import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/copy_util.dart';
import '../../utils/sensitive_data_policy.dart';
import '../../utils/text_truncate.dart';
import '../desktop/pipe.dart';
import 'mq_icons.dart';

/// Masquerade mono output cell. Uppercase caption + mono value + optional copy.
/// Default surface is `monoBg` (= surface3) so code reads on the cream/espresso
/// recess. Accent variant tints with the editorial accent color.
class MqMonoCell extends StatefulWidget {
  const MqMonoCell({
    super.key,
    required this.label,
    required this.value,
    this.copyable = true,
    this.copyValue,
    this.accent = false,
    this.hint,
    this.large = false,
    this.semanticsLabel,
    this.pipeType,
    this.sensitive = false,
  });

  final String label;
  final String value;
  final bool copyable;

  /// Optional unabridged clipboard value when [value] is a display preview.
  final String? copyValue;
  final bool accent;
  final String? hint;
  final bool large;
  final String? semanticsLabel;
  final bool sensitive;

  /// Canvas-only: when non-null AND a [PipeScope] ancestor is present, the cell
  /// becomes a long-press drag source emitting a [PipePayload] of this canonical
  /// type. Null (or no [PipeScope]) leaves the cell exactly as on mobile/Home.
  final ContentType? pipeType;

  /// Longest [value] rendered in full. A longer value renders its first
  /// [maxDisplayChars] characters plus a truncation marker, so a multi-MB
  /// output isn't laid out as one giant paragraph; copy and pipe still carry
  /// the whole string.
  static const int maxDisplayChars = 100000;

  @override
  State<MqMonoCell> createState() => _MqMonoCellState();
}

class _MqMonoCellState extends State<MqMonoCell> {
  // Sensitivity scan memo: four regexes over [value] and [copyValue] (~26 ms
  // per MB of flat text, ~150-220 ms per MB of pretty-printed JSON, VM), so
  // rebuilds that keep both strings (drag frames, parent
  // rebuilds) reuse the last answer.
  String? _scannedValue;
  String? _scannedCopyValue;
  bool _scanned = false;
  bool _containsArtifact = false;

  bool _artifact() {
    final String value = widget.value;
    final String? copyValue = widget.copyValue;
    if (!_scanned || value != _scannedValue || copyValue != _scannedCopyValue) {
      _scanned = true;
      _scannedValue = value;
      _scannedCopyValue = copyValue;
      _containsArtifact =
          SensitiveDataPolicy.containsSensitiveArtifact(value) ||
          (copyValue != null &&
              SensitiveDataPolicy.containsSensitiveArtifact(copyValue));
    }
    return _containsArtifact;
  }

  String? _previewSource;
  String _preview = '';

  /// [MqMonoCell.value] capped at [MqMonoCell.maxDisplayChars], marked the
  /// same way as the CSV output preview.
  String _displayValue() {
    final String value = widget.value;
    if (value.length <= MqMonoCell.maxDisplayChars) return value;
    if (value != _previewSource) {
      _previewSource = value;
      _preview =
          '${truncateWithEllipsis(value, max: MqMonoCell.maxDisplayChars)}'
          ' [preview truncated]';
    }
    return _preview;
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.label;
    final String value = widget.value;
    final String? copyValue = widget.copyValue;
    final bool accent = widget.accent;
    final String? hint = widget.hint;
    final ContentType? pipeType = widget.pipeType;
    final tokens = context.mq;
    final c = tokens.colors;
    final bool protected = widget.sensitive || _artifact();

    final TextStyle valueStyle =
        (widget.large ? MqTextStyles.monoLg : MqTextStyles.monoMd).copyWith(
          color: c.monoText,
        );
    final TextStyle labelStyle = MqTextStyles.sectionLabel.copyWith(
      color: accent ? c.accent : c.textSec,
    );

    final Widget cell = DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? c.accentBg : c.monoBg,
        borderRadius: BorderRadius.circular(MqRadius.sm),
        border: Border.all(color: accent ? c.accent : c.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(label, style: labelStyle)),
                if (widget.copyable)
                  _CopyButton(
                    value: copyValue ?? value,
                    color: c.textTer,
                    sensitive: protected,
                    label: label,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _displayValue(),
              style: valueStyle,
              semanticsLabel: widget.semanticsLabel,
            ),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                hint,
                style: MqTextStyles.caption1.copyWith(
                  color: accent ? c.accentInk : c.textTer,
                  fontFamily: MqTextStyles.monoFamily,
                  fontFamilyFallback: MqTextStyles.monoFallback,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Pipe-drag is canvas-only: inert unless this tool exposes a canonical type
    // AND the cell is inside a card's PipeScope. Mobile/Home have no scope, so
    // the cell renders bit-for-bit as before.
    final PipeScope? scope = pipeType == null || protected
        ? null
        : PipeScope.maybeOf(context);
    if (scope == null) return cell;

    return LongPressDraggable<PipePayload>(
      data: PipePayload(
        type: pipeType!,
        value: value,
        sourceCardId: scope.cardId,
      ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Only one ellipsized line shows; don't shape a multi-MB value per drag.
      feedback: _PipeChip(value: truncateWithEllipsis(value, max: 80)),
      childWhenDragging: Opacity(opacity: 0.4, child: cell),
      child: cell,
    );
  }
}

/// The compact chip that follows the pointer while a cell is being piped. A
/// plain [DecoratedBox] + [Text] so it renders under the CupertinoApp overlay
/// without pulling in any Material chrome.
class _PipeChip extends StatelessWidget {
  const _PipeChip({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.accentBg,
        borderRadius: BorderRadius.circular(MqRadius.sm),
        border: Border.all(color: c.accent, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md,
          vertical: 6,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MqTextStyles.monoSm.copyWith(color: c.accent),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.value,
    required this.color,
    required this.sensitive,
    required this.label,
  });
  final String value;
  final Color color;
  final bool sensitive;
  final String label;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  // Memo for the caption-less semantics preview, which scans [value] again.
  String? _previewValue;
  bool? _previewSensitive;
  String _preview = '';

  String _safePreview() {
    if (_previewValue == null ||
        widget.value != _previewValue ||
        widget.sensitive != _previewSensitive) {
      _previewValue = widget.value;
      _previewSensitive = widget.sensitive;
      _preview = SensitiveDataPolicy.safePreview(
        widget.value,
        max: 32,
        sensitive: widget.sensitive,
      );
    }
    return _preview;
  }

  void _handle() {
    CopyToClipboardUtil.copyToClipboard(
      context,
      widget.value,
      sensitive: widget.sensitive,
    );
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    // Name the button by the cell's caption ("Copy SHA-256"), not a value
    // preview: a screen-reader user tabbing between several copy buttons on
    // one screen (e.g. Hash's four digests) needs to tell them apart, and a
    // truncated hex preview doesn't do that. Cells without a caption (label
    // empty) fall back to today's preview-based label so they don't regress
    // to a bare "Copy".
    final String semanticsLabel = widget.label.isEmpty
        ? 'Copy ${_safePreview()}'
        : 'Copy ${widget.label}';
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: CupertinoButton(
        key: const ValueKey<String>('mqMonoCellCopyTarget'),
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        borderRadius: BorderRadius.circular(MqRadius.sm),
        onPressed: _handle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CopyFlipIcon(
              duration: const Duration(milliseconds: 200),
              showSecond: _copied,
              first: Icon(MqIcons.copy, size: 14, color: widget.color),
              second: Icon(
                MqIcons.check,
                size: 14,
                color: tokens.colors.success,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
