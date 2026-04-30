import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/mb_metrics.dart';
import '../../theme/mb_theme.dart';
import '../../theme/mb_typography.dart';
import 'mb_icons.dart';

class MBUtilityTile extends StatelessWidget {
  const MBUtilityTile({
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
    final tokens = context.mb;
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
            borderRadius: BorderRadius.circular(MBRadius.md),
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
                      borderRadius: BorderRadius.circular(MBRadius.xs + 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 16, color: const Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(width: MBSpacing.sm + 2),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: onToggleFavorite != null ? 16 : 0,
                      ),
                      child: Text(
                        name,
                        style: MBTextStyles.subhead.copyWith(
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
                        favorite ? MBIcons.starFill : MBIcons.star,
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
