import 'package:flutter/cupertino.dart';

import '../../state/canvas_controller.dart';
import '../../theme/mq_metrics.dart';
import '../../theme/mq_theme.dart';
import '../../theme/mq_typography.dart';
import '../mq/mq_icons.dart';

/// Bottom sheet for the desktop "Layouts" sidebar row: save the current canvas
/// under a name, or restore / delete a previously saved [Saved layout].
Future<void> showLayoutsSheet(
  BuildContext context,
  CanvasController controller,
) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext _) => _LayoutsSheet(controller: controller),
  );
}

class _LayoutsSheet extends StatefulWidget {
  const _LayoutsSheet({required this.controller});
  final CanvasController controller;

  @override
  State<_LayoutsSheet> createState() => _LayoutsSheetState();
}

class _LayoutsSheetState extends State<_LayoutsSheet> {
  CanvasController get _c => widget.controller;

  Future<void> _saveCurrent() async {
    final String? name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    _c.saveLayout(name);
    if (mounted) setState(() {});
  }

  void _restore(String name) {
    _c.restoreLayout(name);
    Navigator.of(context).pop();
  }

  void _delete(String name) {
    _c.deleteLayout(name);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<String> names = _c.layoutNames;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MqRadius.lg),
        ),
        border: Border.all(color: c.border, width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Layouts',
              style: MqTextStyles.title3.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.md),
            _SheetTile(
              icon: MqIcons.plus,
              label: 'Save current canvas…',
              tint: c.accent,
              onTap: _c.isEmpty ? null : _saveCurrent,
            ),
            if (names.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
                child: Text(
                  'No saved layouts yet.',
                  style: MqTextStyles.footnote.copyWith(color: c.textTer),
                ),
              )
            else
              for (final String name in names)
                _SheetTile(
                  icon: MqIcons.history,
                  label: name,
                  tint: c.textSec,
                  onTap: () => _restore(name),
                  onTrailingTap: () => _delete(name),
                ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.onTrailingTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final bool enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm + 2),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MqTextStyles.body.copyWith(color: c.textPri),
                ),
              ),
              if (onTrailingTap != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTrailingTap,
                  child: Icon(MqIcons.trash, size: 16, color: c.textTer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _promptName(BuildContext context) {
  final TextEditingController field = TextEditingController();
  final c = context.mq.colors;
  return showCupertinoDialog<String>(
    context: context,
    builder: (BuildContext ctx) {
      return CupertinoAlertDialog(
        title: const Text('Save layout'),
        content: Padding(
          padding: const EdgeInsets.only(top: MqSpacing.md),
          child: CupertinoTextField(
            controller: field,
            autofocus: true,
            placeholder: 'e.g. JWT debug',
            placeholderStyle: MqTextStyles.body.copyWith(color: c.textTer),
            onSubmitted: (String v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(field.text),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
