import 'package:flutter/cupertino.dart';
import 'package:masquerade/utils/copy_util.dart';
import 'package:masquerade/utils/unit_parser.dart';

class UnitConversionDisplayCard extends StatelessWidget {
  const UnitConversionDisplayCard({super.key, required this.result});

  final UnitParseResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _categoryLabel(result.category),
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle
                .copyWith(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...result.conversions.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UnitRow(unit: entry.key, value: entry.value),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(UnitCategory category) {
    switch (category) {
      case UnitCategory.length:
        return 'Length';
      case UnitCategory.weight:
        return 'Weight';
      case UnitCategory.temperature:
        return 'Temperature';
      case UnitCategory.volume:
        return 'Volume';
      case UnitCategory.dataSize:
        return 'Data Size';
      case UnitCategory.timeDuration:
        return 'Time';
      default:
        return 'Conversion';
    }
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unit, required this.value});

  final String unit;
  final double value;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatValue(value);
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            unit,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.secondaryLabel,
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          child: Text(
            formatted,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AnimatedCopyIcon(
          onCopy: () => CopyToClipboardUtil.copyToClipboard(
            context,
            formatted,
          ),
        ),
      ],
    );
  }

  String _formatValue(double value) {
    if (value % 1 == 0 && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    final s = value.toStringAsPrecision(6);
    if (s.contains('.')) {
      return s
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
