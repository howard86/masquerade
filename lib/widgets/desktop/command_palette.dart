import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../../utility_catalog.dart';
import '../mq/mq_icons.dart';

/// Result from the Spotlight command palette: the chosen tool and an optional
/// seed value (non-null when the user's query was detected as a value).
typedef PaletteResult = ({UtilityDescriptor tool, String? seed});

/// Shows the ⌘K Spotlight palette and resolves to the chosen tool + optional
/// seed, or null if the user dismissed it. Searches `UtilityCatalog` by
/// name/synonym and additionally detects pasted values to offer seeded open.
Future<PaletteResult?> showCommandPalette(BuildContext context) {
  return showGeneralDialog<PaletteResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command palette',
    barrierColor: const Color(0x99000000),
    transitionDuration: MqMotion.fast,
    pageBuilder:
        (BuildContext ctx, Animation<double> anim, Animation<double> sec) {
          return const Align(
            alignment: Alignment(0, -0.45),
            child: _CommandPalette(),
          );
        },
    transitionBuilder:
        (
          BuildContext ctx,
          Animation<double> anim,
          Animation<double> sec,
          Widget child,
        ) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: MqMotion.reveal)),
              child: child,
            ),
          );
        },
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<UtilityDescriptor> _results = UtilityCatalog.searchByName('');
  UtilityDescriptor? _detected;
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(_recompute);
  }

  @override
  void dispose() {
    _query.removeListener(_recompute);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _recompute() {
    final String text = _query.text;
    final List<UtilityDescriptor> detected = UtilityCatalog.detectAll(text);
    setState(() {
      _results = UtilityCatalog.searchByName(text);
      _detected = detected.isNotEmpty ? detected.first : null;
      _highlight = 0;
    });
  }

  int get _totalRows => (_detected != null ? 1 : 0) + _results.length;

  void _pick(UtilityDescriptor u, {String? seed}) =>
      Navigator.of(context).pop((tool: u, seed: seed));

  void _pickHighlighted() {
    if (_detected != null && _highlight == 0) {
      _pick(_detected!, seed: _query.text);
    } else {
      final int idx = _highlight - (_detected != null ? 1 : 0);
      if (idx >= 0 && idx < _results.length) _pick(_results[idx]);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_totalRows > 0) {
        setState(() => _highlight = (_highlight + 1) % _totalRows);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      if (_totalRows > 0) {
        setState(() => _highlight = (_highlight - 1 + _totalRows) % _totalRows);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_totalRows > 0) _pickHighlighted();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Focus(
      onKeyEvent: _onKey,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MqRadius.md),
          border: Border.all(color: c.borderStrong, width: 0.5),
          boxShadow: c.shadowLg,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MqRadius.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SearchField(controller: _query, focusNode: _focus),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: MqSpacing.xs),
                  itemCount: _totalRows,
                  itemBuilder: (BuildContext _, int i) {
                    if (_detected != null && i == 0) {
                      return _DetectRow(
                        descriptor: _detected!,
                        highlighted: _highlight == 0,
                        onTap: () => _pick(_detected!, seed: _query.text),
                      );
                    }
                    final int idx = i - (_detected != null ? 1 : 0);
                    final UtilityDescriptor u = _results[idx];
                    return _ResultRow(
                      descriptor: u,
                      highlighted: i == _highlight,
                      onTap: () => _pick(u),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.md,
        vertical: MqSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(MqIcons.search, size: 16, color: c.textTer),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: CupertinoTextField(
              key: const ValueKey<String>('command-palette-field'),
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              placeholder: 'Open a tool…',
              placeholderStyle: MqTextStyles.body.copyWith(color: c.textTer),
              style: MqTextStyles.body.copyWith(color: c.textPri),
              decoration: const BoxDecoration(),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.descriptor,
    required this.highlighted,
    required this.onTap,
  });

  final UtilityDescriptor descriptor;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: highlighted ? c.accentBg : null,
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              Icon(descriptor.icon, size: 18, color: descriptor.tint),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      descriptor.name,
                      style: MqTextStyles.body.copyWith(
                        color: highlighted ? c.accent : c.textPri,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      descriptor.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MqTextStyles.caption1.copyWith(color: c.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectRow extends StatelessWidget {
  const _DetectRow({
    required this.descriptor,
    required this.highlighted,
    required this.onTap,
  });

  final UtilityDescriptor descriptor;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: highlighted ? c.accentBg : null,
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md,
            vertical: MqSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              Icon(descriptor.icon, size: 18, color: descriptor.tint),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Text(
                  'Open ${descriptor.name} with this value',
                  style: MqTextStyles.body.copyWith(
                    color: highlighted ? c.accent : c.textPri,
                    fontWeight: FontWeight.w600,
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
