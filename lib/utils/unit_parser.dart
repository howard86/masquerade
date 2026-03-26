import 'package:masquerade/utils/encoding_parser.dart';

enum UnitCategory {
  length,
  weight,
  temperature,
  volume,
  dataSize,
  timeDuration,
  timestamp,
  encoding,
  unknown,
}

class UnitParseResult {
  const UnitParseResult({
    required this.isSuccess,
    required this.category,
    this.fromValue = 0,
    this.fromUnit = '',
    this.conversions = const {},
    this.errorMessage,
    this.timestamp,
    this.encodingResult,
  });

  final bool isSuccess;
  final UnitCategory category;
  final double fromValue;
  final String fromUnit;
  final Map<String, double> conversions;
  final String? errorMessage;
  final DateTime? timestamp;
  final EncodingResult? encodingResult;

  static const UnitParseResult empty = UnitParseResult(
    isSuccess: false,
    category: UnitCategory.unknown,
  );
}
