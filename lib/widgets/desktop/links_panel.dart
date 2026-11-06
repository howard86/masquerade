import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../../state/canvas_controller.dart';
import '../../state/link_group.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utils/sensitive_data_policy.dart';
import '../mq/mq_icons.dart';
import 'link_identity.dart';

const double _rowHeight = 36;
const double _rowGap = MqSpacing.xs;
const double _spokeWidth = 36;

/// Node-graph overview of every live-link group: one star per group, with the
/// canonical value at the hub and each linked window as a spoke.
class LinksPanel extends StatelessWidget {
  const LinksPanel({super.key, required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final List<LinkGroup> groups = controller.groups.toList()
          ..sort((LinkGroup a, LinkGroup b) => a.id.compareTo(b.id));
        if (groups.isEmpty) return const _EmptyState();
        final Map<int, LinkIdentity> ids = linkIdentities(groups, c);
        return ListView(
          padding: const EdgeInsets.all(MqSpacing.md),
          children: <Widget>[
            for (final LinkGroup g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.md),
                child: _GroupGraph(
                  controller: controller,
                  group: g,
                  identity: ids[g.id]!,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(MqIcons.link, size: 28, color: c.textTer),
            const SizedBox(height: MqSpacing.sm),
            Text(
              'No live links yet',
              style: MqTextStyles.headline.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.xs),
            Text(
              'Click the link button in a window’s title bar, or drag an '
              'output cell onto another window, to keep their values in sync.',
              textAlign: TextAlign.center,
              style: MqTextStyles.footnote.copyWith(color: c.textSec),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGraph extends StatelessWidget {
  const _GroupGraph({
    required this.controller,
    required this.group,
    required this.identity,
  });

  final CanvasController controller;
  final LinkGroup group;
  final LinkIdentity identity;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<CanvasCard> members = <CanvasCard>[
      for (final CanvasCard card in controller.cards)
        if (group.members.contains(card.id)) card,
    ];
    final double height =
        members.length * _rowHeight + (members.length - 1) * _rowGap;
    final List<bool> followers = <bool>[
      for (final CanvasCard m in members) controller.isFollower(m.id),
    ];
    final int following = followers.where((bool f) => f).length;
    final String summary =
        'Link group ${identity.letter}, ${contentTypeLabel(group.type)}, '
        '${members.map((CanvasCard m) => m.content.title).join(', ')}. '
        '${members.length} windows'
        '${following > 0 ? ', $following following' : ''}';
    return Semantics(
      container: true,
      label: summary,
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.sm),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border, width: 0.5),
          borderRadius: BorderRadius.circular(MqRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: height < _rowHeight ? _rowHeight : height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 112,
                    child: Center(
                      child: _HubNode(
                        group: group,
                        identity: identity,
                        sensitive: controller.groupIsSensitive(group),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _spokeWidth,
                    child: CustomPaint(
                      painter: _SpokePainter(
                        followers: followers,
                        color: identity.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < members.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: _rowGap),
                          SizedBox(
                            height: _rowHeight,
                            child: _MemberNode(
                              controller: controller,
                              card: members[i],
                              identity: identity,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubNode extends StatelessWidget {
  const _HubNode({
    required this.group,
    required this.identity,
    required this.sensitive,
  });

  final LinkGroup group;
  final LinkIdentity identity;
  final bool sensitive;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.sm,
        vertical: MqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: identity.color.withValues(alpha: 0.14),
        border: Border.all(color: identity.color, width: 1.5),
        borderRadius: BorderRadius.circular(MqRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                identity.letter,
                style: MqTextStyles.headline.copyWith(color: identity.color),
              ),
              const SizedBox(width: MqSpacing.xs),
              Flexible(
                child: Text(
                  contentTypeLabel(group.type),
                  overflow: TextOverflow.ellipsis,
                  style: MqTextStyles.caption1.copyWith(color: c.textSec),
                ),
              ),
            ],
          ),
          ValueListenableBuilder<String>(
            valueListenable: group.canonical,
            builder: (BuildContext context, String value, _) => Text(
              SensitiveDataPolicy.safePreview(
                value,
                max: 32,
                sensitive: sensitive,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MqTextStyles.monoSm.copyWith(color: c.textPri),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberNode extends StatelessWidget {
  const _MemberNode({
    required this.controller,
    required this.card,
    required this.identity,
  });

  final CanvasController controller;
  final CanvasCard card;
  final LinkIdentity identity;

  void _focus() {
    if (card.minimized) controller.restoreWindow(card.id);
    controller.focus(card.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final String name = card.content.title;
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: card.minimized ? 'Focus $name (minimized)' : 'Focus $name',
            excludeSemantics: true,
            onTap: _focus,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focus,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border, width: 0.5),
                  borderRadius: BorderRadius.circular(MqRadius.sm),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(card.content.icon, size: 14, color: card.content.tint),
                    const SizedBox(width: MqSpacing.xs),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MqTextStyles.footnote.copyWith(color: c.textPri),
                      ),
                    ),
                    if (card.minimized)
                      Text(
                        'minimized',
                        style: MqTextStyles.caption2.copyWith(color: c.textTer),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _FollowToggle(
          name: name,
          follows: controller.isFollower(card.id),
          enabled:
              controller.canFollow(card.id) || controller.isFollower(card.id),
          color: identity.color,
          onChanged: (bool v) => controller.setFollower(card.id, v),
        ),
        Semantics(
          button: true,
          label: 'Unlink $name from group ${identity.letter}',
          excludeSemantics: true,
          onTap: () => controller.unlinkCard(card.id),
          child: CupertinoButton(
            padding: const EdgeInsets.all(MqSpacing.xs),
            minimumSize: const Size(28, 28),
            onPressed: () => controller.unlinkCard(card.id),
            child: Icon(MqIcons.clear, size: 16, color: c.textTer),
          ),
        ),
      ],
    );
  }
}

class _FollowToggle extends StatelessWidget {
  const _FollowToggle({
    required this.name,
    required this.follows,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });

  final String name;
  final bool follows;
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onChanged;

  void _toggle() => onChanged(!follows);

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final Color fg = follows ? color : c.textSec;
    return Semantics(
      button: true,
      toggled: follows,
      enabled: enabled,
      label: '$name follow only',
      hint: enabled ? null : 'At least one window must send',
      excludeSemantics: true,
      onTap: enabled ? _toggle : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            margin: const EdgeInsets.only(left: MqSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.xs,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: follows ? color.withValues(alpha: 0.14) : null,
              border: Border.all(color: follows ? color : c.border, width: 0.5),
              borderRadius: BorderRadius.circular(MqRadius.sm),
            ),
            child: Text(
              'Follow only',
              style: MqTextStyles.caption2.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpokePainter extends CustomPainter {
  const _SpokePainter({required this.followers, required this.color});

  final List<bool> followers;
  final Color color;

  void _arrowhead(Canvas canvas, Paint paint, Offset tip, Offset from) {
    final Offset d = (from - tip) / (from - tip).distance;
    final Offset n = Offset(-d.dy, d.dx);
    const double len = 7;
    const double half = 3.5;
    final Offset base = tip + d * len;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + n.dx * half, base.dy + n.dy * half)
        ..lineTo(base.dx - n.dx * half, base.dy - n.dy * half)
        ..close(),
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Offset hub = Offset(0, size.height / 2);
    for (int i = 0; i < followers.length; i++) {
      final Offset end = Offset(
        size.width,
        i * (_rowHeight + _rowGap) + _rowHeight / 2,
      );
      canvas.drawLine(hub, end, paint);
      if (followers[i]) _arrowhead(canvas, paint, end, hub);
    }
  }

  @override
  bool shouldRepaint(_SpokePainter old) =>
      !listEquals(old.followers, followers) || old.color != color;
}
