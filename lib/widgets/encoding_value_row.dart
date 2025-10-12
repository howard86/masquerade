import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:masquerade/utils/copy_util.dart';

/// A stateless widget that displays a value row with label and copyable value
class EncodingValueRow extends StatelessWidget {
  const EncodingValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(
                        fontSize: 14,
                        fontFamily: 'Courier',
                        color: color,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedCopyIcon(
                onCopy: () =>
                    CopyToClipboardUtil.copyToClipboard(context, value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
