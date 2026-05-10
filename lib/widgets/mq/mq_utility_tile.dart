import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_colors.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

/// Editorial utility tile — flat surface + hairline border, accent on press.
class MqUtilityTile extends StatefulWidget {
  const MqUtilityTile({
    super.key,
    required this.name,
    required this.icon,
    required this.tint,
    this.description,
    this.onTap,
    this.compact = false,
  });

  final String name;
  final IconData icon;
  final Color tint;

  final String? description;
  final VoidCallback? onTap;

  /// `false` → square-ish vertical layout for grid tiles.
  /// `true`  → slim horizontal row for list contexts (e.g. search results).
  final bool compact;

  @override
  State<MqUtilityTile> createState() => _MqUtilityTileState();
}

class _MqUtilityTileState extends State<MqUtilityTile> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (v != _pressed) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    final BoxDecoration surface = BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(MqRadius.md),
      border: Border.all(
        color: _pressed ? c.accent : c.border,
        width: _pressed ? 1.0 : 0.5,
      ),
    );

    final Widget content = widget.compact
        ? _buildCompact(c)
        : _buildVertical(c);

    return Semantics(
      button: true,
      label: widget.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: Container(
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: surface,
          child: content,
        ),
      ),
    );
  }

  Widget _buildVertical(MqColors c) {
    final String? desc = widget.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(MqRadius.sm),
            border: Border.all(
              color: widget.tint.withValues(alpha: 0.32),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: widget.tint),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.name,
                style: MqTextStyles.headline.copyWith(color: c.textPri),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (desc != null) ...<Widget>[
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    desc,
                    style: MqTextStyles.caption1.copyWith(color: c.textSec),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(MqColors c) {
    final String? desc = widget.description;
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(MqRadius.xs + 2),
            border: Border.all(
              color: widget.tint.withValues(alpha: 0.32),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 14, color: widget.tint),
        ),
        const SizedBox(width: MqSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.name,
                style: MqTextStyles.subhead.copyWith(
                  color: c.textPri,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (desc != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: MqTextStyles.caption1.copyWith(color: c.textSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
