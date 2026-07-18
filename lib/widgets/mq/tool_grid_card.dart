import 'package:flutter/cupertino.dart';

import '../../state/history_controller.dart';
import '../../theme/mq_density.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../../utils/sensitive_data_policy.dart';
import 'mq_icons.dart';

/// Editorial home-grid tile. Hairline border resting; accent border + pulsing
/// dot when [matched]; mono preview line when [lastEntry] is present
/// (sensitive entries mask the preview with bullets).
class ToolGridCard extends StatelessWidget {
  const ToolGridCard({
    super.key,
    required this.descriptor,
    required this.matched,
    required this.lastEntry,
    required this.onTap,
    this.onLongPress,
    this.favorite = false,
    this.onToggleFavorite,
    this.showMetadata = false,
  });

  final UtilityDescriptor descriptor;
  final bool matched;
  final HistoryEntry? lastEntry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool favorite;
  final VoidCallback? onToggleFavorite;
  final bool showMetadata;

  static const int _previewMax = 24;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final MqDensity d = context.density;
    final HistoryEntry? entry = lastEntry;
    final bool hasPreview = entry != null;
    final String? preview = hasPreview
        ? SensitiveDataPolicy.safePreview(
            entry.input,
            max: _previewMax,
            utilityId: entry.utilityId,
            sensitive: entry.sensitive,
          )
        : null;
    final Color borderColor = matched ? c.accent : c.border;
    final double borderWidth = matched ? 1.0 : 0.5;

    return Semantics(
      button: true,
      label: descriptor.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.all(d.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MqRadius.md),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(descriptor.icon, size: 18, color: descriptor.tint),
                  const SizedBox(width: MqSpacing.sm),
                  Expanded(
                    child: Text(
                      descriptor.name,
                      style: MqTextStyles.headline.copyWith(color: c.textPri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onToggleFavorite != null)
                    Semantics(
                      label: 'Favorite ${descriptor.name}',
                      button: true,
                      toggled: favorite,
                      excludeSemantics: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(44),
                        onPressed: onToggleFavorite,
                        child: Icon(
                          MqIcons.star,
                          size: 18,
                          color: favorite ? c.accent : c.textTer,
                        ),
                      ),
                    ),
                  if (matched) ...<Widget>[
                    const SizedBox(width: MqSpacing.xs),
                    _MatchDot(color: c.accent),
                  ],
                ],
              ),
              const SizedBox(height: MqSpacing.xs),
              hasPreview
                  ? Text(
                      preview!,
                      style: MqTextStyles.monoSm.copyWith(color: c.textTer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      showMetadata
                          ? descriptor.metadataSummary
                          : descriptor.description,
                      style: MqTextStyles.caption1.copyWith(color: c.textSec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchDot extends StatelessWidget {
  const _MatchDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
