import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:masquerade/widgets/encoding_value_row.dart';

/// A card widget that displays encoding information for hex and base64 inputs.
class EncodingDisplayCard extends StatelessWidget {
  const EncodingDisplayCard({
    super.key,
    required this.originalValue,
    required this.encodingType,
    required this.decodedValue,
  });

  final String originalValue;
  final String encodingType;
  final String decodedValue;

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
          // Header
          Row(
            children: [
              Icon(
                _getIconForEncodingType(encodingType),
                color: _getColorForEncodingType(encodingType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${encodingType.toUpperCase()} Encoding',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getColorForEncodingType(encodingType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Show decoded value if it exists
          if (decodedValue.isNotEmpty) ...[
            EncodingValueRow(
              label: 'Decoded',
              value: decodedValue,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(height: 12),
            EncodingValueRow(
              label: 'Base64',
              value: _stringToBase64(originalValue),
              color: CupertinoColors.systemGreen,
            ),
            const SizedBox(height: 12),
            EncodingValueRow(
              label: 'Hex',
              value: _stringToHex(originalValue),
              color: CupertinoColors.systemOrange,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForEncodingType(String type) {
    switch (type.toLowerCase()) {
      case 'hex':
        return CupertinoIcons.number;
      case 'base64':
        return CupertinoIcons.textformat_abc;
      default:
        return CupertinoIcons.info_circle;
    }
  }

  Color _getColorForEncodingType(String type) {
    switch (type.toLowerCase()) {
      case 'hex':
        return CupertinoColors.systemOrange;
      case 'base64':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemBlue;
    }
  }

  String _stringToHex(String input) {
    return input.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join('');
  }

  String _stringToBase64(String input) {
    return base64Encode(input.codeUnits);
  }
}
