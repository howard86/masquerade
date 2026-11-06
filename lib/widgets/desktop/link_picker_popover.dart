import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_colors.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../mq/mq_input.dart';

/// One selectable row in a [LinkPickerPopover].
class LinkPickerRow<T> {
  const LinkPickerRow({
    required this.value,
    required this.name,
    required this.icon,
    required this.semanticsLabel,
    this.tags = const <Widget>[],
  });

  final T value;

  /// Visible tool name; also what the filter field matches against.
  final String name;
  final IconData icon;
  final String semanticsLabel;

  /// Trailing chips, shown on the right of the row.
  final List<Widget> tags;
}

/// A titled group of rows (e.g. "Open windows").
class LinkPickerSection<T> {
  const LinkPickerSection({required this.title, required this.rows});

  final String title;
  final List<LinkPickerRow<T>> rows;
}

/// What the popover resolves to when a row is chosen.
typedef LinkPickerResult<T> = ({T value, bool follows});

/// Shows the link-target picker as an anchored desktop popover. Resolves to
/// the chosen row (plus the follow checkbox state), or null when dismissed.
///
/// [anchor] is the invoking control's global rect; a zero-size rect anchors at
/// a click position. [followLabel] null hides the follow checkbox;
/// [initialFollows] is its starting state.
Future<LinkPickerResult<T>?> showLinkPickerPopover<T>(
  BuildContext context, {
  required Rect anchor,
  required String title,
  required String explanation,
  List<String> notes = const <String>[],
  String? followLabel,
  bool initialFollows = false,
  required List<LinkPickerSection<T>> sections,
}) {
  return Navigator.of(context, rootNavigator: true).push<LinkPickerResult<T>>(
    _LinkPickerRoute<T>(
      anchor: anchor,
      title: title,
      explanation: explanation,
      notes: notes,
      followLabel: followLabel,
      initialFollows: initialFollows,
      sections: sections,
    ),
  );
}

class _LinkPickerRoute<T> extends PopupRoute<LinkPickerResult<T>> {
  _LinkPickerRoute({
    required this.anchor,
    required this.title,
    required this.explanation,
    required this.notes,
    required this.followLabel,
    required this.initialFollows,
    required this.sections,
  });

  final Rect anchor;
  final String title;
  final String explanation;
  final List<String> notes;
  final String? followLabel;
  final bool initialFollows;
  final List<LinkPickerSection<T>> sections;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss link picker';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 90);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: LinkPickerPopover<T>(
        anchor: anchor,
        title: title,
        explanation: explanation,
        notes: notes,
        followLabel: followLabel,
        initialFollows: initialFollows,
        sections: sections,
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout(this.anchor);

  final Rect anchor;
  static const double _margin = 8;
  static const double _gap = 6;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          LinkPickerPopover.width.clamp(0, constraints.maxWidth - _margin * 2),
          constraints.maxHeight * 0.6,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Right-align under the anchor so the popover opens over its own window
    // (the link button sits at a window's right edge); fall back to
    // left-aligning when that would run off the left side.
    double left = anchor.right - childSize.width;
    if (left < _margin) left = anchor.left;
    left = left.clamp(
      _margin,
      (size.width - childSize.width - _margin).clamp(_margin, double.infinity),
    );
    final double gap = anchor.isEmpty ? 0 : _gap;
    double top = anchor.bottom + gap;
    if (top + childSize.height > size.height - _margin) {
      final double above = anchor.top - gap - childSize.height;
      top = above >= _margin ? above : size.height - childSize.height - _margin;
    }
    top = top.clamp(_margin, double.infinity);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) => old.anchor != anchor;
}

/// Popover body; exposed for the route, not meant to be placed directly.
class LinkPickerPopover<T> extends StatefulWidget {
  const LinkPickerPopover({
    super.key,
    required this.anchor,
    required this.title,
    required this.explanation,
    required this.notes,
    required this.followLabel,
    this.initialFollows = false,
    required this.sections,
  });

  static const double width = 340;

  final Rect anchor;
  final String title;
  final String explanation;
  final List<String> notes;
  final String? followLabel;
  final bool initialFollows;
  final List<LinkPickerSection<T>> sections;

  @override
  State<LinkPickerPopover<T>> createState() => _LinkPickerPopoverState<T>();
}

class _LinkPickerPopoverState<T> extends State<LinkPickerPopover<T>> {
  final TextEditingController _filter = TextEditingController();
  final FocusNode _filterFocus = FocusNode();
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  late bool _follows = widget.initialFollows;
  int _highlight = 0;

  bool get _noTargets =>
      widget.sections.every((LinkPickerSection<T> s) => s.rows.isEmpty);

  List<LinkPickerSection<T>> get _visible {
    final String q = _filter.text.trim().toLowerCase();
    return <LinkPickerSection<T>>[
      for (final LinkPickerSection<T> s in widget.sections)
        if (s.rows.any(
          (LinkPickerRow<T> r) => r.name.toLowerCase().contains(q),
        ))
          LinkPickerSection<T>(
            title: s.title,
            rows: <LinkPickerRow<T>>[
              for (final LinkPickerRow<T> r in s.rows)
                if (r.name.toLowerCase().contains(q)) r,
            ],
          ),
    ];
  }

  List<LinkPickerRow<T>> get _flat => <LinkPickerRow<T>>[
    for (final LinkPickerSection<T> s in _visible) ...s.rows,
  ];

  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  void _choose(LinkPickerRow<T> row) {
    Navigator.of(
      context,
    ).pop<LinkPickerResult<T>>((value: row.value, follows: _follows));
  }

  void _move(int delta) {
    final int n = _flat.length;
    if (n == 0) return;
    setState(() => _highlight = (_highlight + delta).clamp(0, n - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = _rowKeys[_highlight]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.5);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      final List<LinkPickerRow<T>> flat = _flat;
      if (flat.isNotEmpty && event is KeyDownEvent) {
        _choose(flat[_highlight.clamp(0, flat.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final MqColors c = context.mq.colors;
    final List<LinkPickerSection<T>> visible = _visible;
    int index = 0;
    final List<Widget> list = <Widget>[];
    for (final LinkPickerSection<T> s in visible) {
      list.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MqSpacing.md,
            MqSpacing.sm,
            MqSpacing.md,
            MqSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.title,
              textAlign: TextAlign.left,
              style: MqTextStyles.sectionLabel.copyWith(color: c.textSec),
            ),
          ),
        ),
      );
      for (final LinkPickerRow<T> r in s.rows) {
        final int i = index++;
        // Keys must survive rebuilds: a fresh GlobalKey remounts the row,
        // which drops an in-flight tap and re-fires the hover callback.
        final GlobalKey key = _rowKeys.putIfAbsent(i, GlobalKey.new);
        list.add(
          _RowTile<T>(
            key: key,
            row: r,
            highlighted: i == _highlight,
            onHover: () {
              if (_highlight != i) setState(() => _highlight = i);
            },
            onTap: () => _choose(r),
          ),
        );
      }
    }
    final bool noTargets = _noTargets;
    if (list.isEmpty && !noTargets) {
      list.add(
        Padding(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No tools match "${_filter.text.trim()}".',
              textAlign: TextAlign.left,
              style: MqTextStyles.caption1.copyWith(color: c.textSec),
            ),
          ),
        ),
      );
    }

    return CustomSingleChildLayout(
      delegate: _PopoverLayout(widget.anchor),
      child: Focus(
        // The filter field takes focus when shown (its keys still bubble to
        // [_onKey]); two autofocus requests would leave typing nowhere.
        autofocus: _noTargets,
        onKeyEvent: _onKey,
        child: Container(
          width: LinkPickerPopover.width,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(MqRadius.sm),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: c.shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.md,
                  MqSpacing.md,
                  MqSpacing.md,
                  MqSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      textAlign: TextAlign.left,
                      style: MqTextStyles.headline.copyWith(color: c.textPri),
                    ),
                    const SizedBox(height: MqSpacing.xs),
                    Text(
                      widget.explanation,
                      textAlign: TextAlign.left,
                      style: MqTextStyles.caption1.copyWith(color: c.textSec),
                    ),
                    for (final String note in widget.notes) ...<Widget>[
                      const SizedBox(height: MqSpacing.xs),
                      Text(
                        note,
                        textAlign: TextAlign.left,
                        style: MqTextStyles.caption1.copyWith(color: c.warning),
                      ),
                    ],
                    if (!noTargets && widget.followLabel != null) ...<Widget>[
                      const SizedBox(height: MqSpacing.sm),
                      _FollowToggle(
                        label: widget.followLabel!,
                        value: _follows,
                        onChanged: (bool v) => setState(() => _follows = v),
                      ),
                    ],
                    if (!noTargets) ...<Widget>[
                      const SizedBox(height: MqSpacing.sm),
                      MqInput(
                        controller: _filter,
                        placeholder: 'Filter tools',
                        mono: false,
                        autofocus: true,
                        focusNode: _filterFocus,
                        semanticsLabel: 'Filter tools',
                        onChanged: (_) => setState(() => _highlight = 0),
                      ),
                    ],
                  ],
                ),
              ),
              if (list.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: MqSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: list,
                    ),
                  ),
                )
              else
                const SizedBox(height: MqSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowTile<T> extends StatelessWidget {
  const _RowTile({
    super.key,
    required this.row,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final LinkPickerRow<T> row;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MqColors c = context.mq.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: Semantics(
        label: row.semanticsLabel,
        button: true,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            color: highlighted ? c.accentBg : const Color(0x00000000),
            padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.md,
              vertical: MqSpacing.xs + 2,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  row.icon,
                  size: 16,
                  color: highlighted ? c.accent : c.textSec,
                ),
                const SizedBox(width: MqSpacing.sm),
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: MqTextStyles.subhead.copyWith(
                      color: highlighted ? c.accent : c.textPri,
                      fontWeight: highlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                for (final Widget tag in row.tags) ...<Widget>[
                  const SizedBox(width: MqSpacing.xs),
                  tag,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowToggle extends StatelessWidget {
  const _FollowToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final MqColors c = context.mq.colors;
    return Semantics(
      label: label,
      checked: value,
      button: true,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                value
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 18,
                color: value ? c.accent : c.textSec,
              ),
              const SizedBox(width: MqSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.left,
                  style: MqTextStyles.caption1.copyWith(color: c.textPri),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
