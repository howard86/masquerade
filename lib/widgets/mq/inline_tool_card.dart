import 'package:flutter/widgets.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import 'mq_icons.dart';

/// Tool selector that morphs between a pill chip (collapsed) and a banner
/// (expanded). Body unfurls beneath via [AnimatedSize] on the editorial
/// reveal/dismiss curves — no overshoot. Header text uses Plex Serif at the
/// expanded size for the "tool name as title" feel.
class InlineToolCard extends StatelessWidget {
  const InlineToolCard({
    super.key,
    required this.descriptor,
    required this.expanded,
    required this.onToggle,
    required this.bodyBuilder,
    this.bodyKey,
    this.previewText,
    this.previewSensitive = false,
  });

  final UtilityDescriptor descriptor;
  final bool expanded;
  final VoidCallback onToggle;
  final WidgetBuilder bodyBuilder;
  final Key? bodyKey;
  final String? previewText;
  final bool previewSensitive;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color chipBg = expanded ? c.accentBg : const Color(0x00000000);
    final Color chipBorder = expanded ? c.accent : c.border;
    final Color textColor = expanded ? c.accent : c.textPri;

    final Widget header = AnimatedContainer(
      duration: MqMotion.normal,
      curve: expanded ? MqMotion.reveal : MqMotion.dismiss,
      padding: expanded
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(
          expanded ? MqRadius.sm : MqRadius.pill,
        ),
        border: Border.all(color: chipBorder, width: 0.5),
      ),
      child: AnimatedSwitcher(
        duration: MqMotion.fast,
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[...previous, ?current],
        ),
        child: expanded
            ? _ExpandedHeaderRow(
                key: const ValueKey<String>('expanded'),
                descriptor: descriptor,
                color: textColor,
              )
            : _CollapsedHeaderRow(
                key: const ValueKey<String>('collapsed'),
                descriptor: descriptor,
                color: textColor,
                previewText: previewText,
                previewSensitive: previewSensitive,
              ),
      ),
    );

    final Widget tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: header,
    );

    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? 'Collapse ${descriptor.name}' : descriptor.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: expanded
                ? SizedBox(width: double.infinity, child: tappable)
                : tappable,
          ),
          ClipRect(
            child: AnimatedSize(
              duration: MqMotion.normal,
              curve: expanded ? MqMotion.reveal : MqMotion.dismiss,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, MqSpacing.md, 0, 0),
                      child: Builder(key: bodyKey, builder: bodyBuilder),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedHeaderRow extends StatelessWidget {
  const _CollapsedHeaderRow({
    super.key,
    required this.descriptor,
    required this.color,
    required this.previewText,
    required this.previewSensitive,
  });

  final UtilityDescriptor descriptor;
  final Color color;
  final String? previewText;
  final bool previewSensitive;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String? preview = previewText;
    final bool hasPreview = preview != null && preview.isNotEmpty;
    final Widget nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(descriptor.icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          descriptor.name,
          style: MqTextStyles.subhead.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (!hasPreview) return nameRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        nameRow,
        const SizedBox(height: 2),
        Text(
          previewSensitive ? '••••' : preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MqTextStyles.caption1.copyWith(
            color: c.textTer,
            fontFamily: MqTextStyles.monoFamily,
            fontFamilyFallback: MqTextStyles.monoFallback,
          ),
        ),
      ],
    );
  }
}

class _ExpandedHeaderRow extends StatelessWidget {
  const _ExpandedHeaderRow({
    super.key,
    required this.descriptor,
    required this.color,
  });

  final UtilityDescriptor descriptor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(MqIcons.chevL, size: 16, color: color),
        const SizedBox(width: 6),
        Icon(descriptor.icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            descriptor.name,
            style: MqTextStyles.title3.copyWith(
              fontFamily: MqTextStyles.serifFamily,
              fontFamilyFallback: MqTextStyles.serifFallback,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(MqIcons.xmark, size: 14, color: color),
      ],
    );
  }
}
