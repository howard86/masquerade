import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_colors.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';

class MqUtilityTile extends StatelessWidget {
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

  /// One-line subtitle. Rendered below the name when provided.
  final String? description;
  final VoidCallback? onTap;

  /// `false` → square-ish vertical layout for grid tiles.
  /// `true`  → slim horizontal row for list contexts (e.g. search results).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    final BoxDecoration surface = BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(MqRadius.md),
      border: Border.all(color: c.border, width: 0.5),
      boxShadow: c.shadow,
    );

    final Widget content = compact ? _buildCompact(c) : _buildVertical(c);

    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: surface,
          child: content,
        ),
      ),
    );
  }

  Widget _buildVertical(MqColors c) {
    final String? desc = description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(MqRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: const Color(0xFFFFFFFF)),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
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
    final String? desc = description;
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(MqRadius.xs + 2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: const Color(0xFFFFFFFF)),
        ),
        const SizedBox(width: MqSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
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
