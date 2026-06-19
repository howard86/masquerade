import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/copy_util.dart';
import '../desktop/pipe.dart';
import 'mq_icons.dart';

/// Masquerade mono output cell. Uppercase caption + mono value + optional copy.
/// Default surface is `monoBg` (= surface3) so code reads on the cream/espresso
/// recess. Accent variant tints with the editorial accent color.
class MqMonoCell extends StatelessWidget {
  const MqMonoCell({
    super.key,
    required this.label,
    required this.value,
    this.copyable = true,
    this.accent = false,
    this.hint,
    this.large = false,
    this.semanticsLabel,
    this.pipeType,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool accent;
  final String? hint;
  final bool large;
  final String? semanticsLabel;

  /// Canvas-only: when non-null AND a [PipeScope] ancestor is present, the cell
  /// becomes a long-press drag source emitting a [PipePayload] of this canonical
  /// type. Null (or no [PipeScope]) leaves the cell exactly as on mobile/Home.
  final ContentType? pipeType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    final TextStyle valueStyle =
        (large ? MqTextStyles.monoLg : MqTextStyles.monoMd).copyWith(
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
                if (copyable) _CopyButton(value: value, color: c.textTer),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: valueStyle, semanticsLabel: semanticsLabel),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: MqTextStyles.caption1.copyWith(
                  color: c.textTer,
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
    final PipeScope? scope = pipeType == null
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
      feedback: _PipeChip(value: value),
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
  const _CopyButton({required this.value, required this.color});
  final String value;
  final Color color;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _handle() {
    CopyToClipboardUtil.copyToClipboard(context, widget.value);
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    return Semantics(
      button: true,
      label: 'Copy ${widget.value}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handle,
        // Grow the tappable region to the 44×44 iOS HIG minimum without
        // enlarging the glyph: a min-size box centers the unchanged icon so a
        // tap anywhere in the 44×44 area copies, while the visual stays put.
        child: ConstrainedBox(
          key: const ValueKey<String>('mqMonoCellCopyTarget'),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? MqIcons.check : MqIcons.copy,
                  key: ValueKey<bool>(_copied),
                  size: 14,
                  color: _copied ? tokens.colors.success : widget.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
