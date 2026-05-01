import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import 'mq_icons.dart';

class MqUtilityTile extends StatelessWidget {
  const MqUtilityTile({
    super.key,
    required this.name,
    required this.icon,
    required this.tint,
    this.onTap,
    this.favorite = false,
    this.onToggleFavorite,
  });

  final String name;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mq;
    final c = tokens.colors;

    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MqRadius.md),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: c.shadow,
          ),
          child: Stack(
            children: <Widget>[
              Row(
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
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: onToggleFavorite != null ? 16 : 0,
                      ),
                      child: Text(
                        name,
                        style: MqTextStyles.subhead.copyWith(
                          color: c.textPri,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (onToggleFavorite != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        favorite ? MqIcons.starFill : MqIcons.star,
                        size: 12,
                        color: favorite ? c.warning : c.textTer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
