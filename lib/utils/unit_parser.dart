import 'package:masquerade/utils/encoding_parser.dart';
import 'package:masquerade/utils/timestamp_parser.dart';

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

  factory UnitParseResult.error(String message) => UnitParseResult(
    isSuccess: false,
    category: UnitCategory.unknown,
    errorMessage: message,
  );
}

class UnitParser {
  // Regex to split "100km" or "100 km" or "-40.5 F" into value + unit
  static final RegExp _valueUnitRegex = RegExp(r'^(-?[\d.]+)\s*(.+)$');

  // Canonical unit name → conversion factor relative to the category base unit
  // Length base: m | Weight base: g | Volume base: ml
  // Data size base: B | Time base: ms
  static const Map<String, double> _conversionFactors = {
    // Length (base: m)
    'mm': 0.001, 'cm': 0.01, 'm': 1.0, 'km': 1000.0,
    'in': 0.0254, 'ft': 0.3048, 'yd': 0.9144, 'mi': 1609.344,
    // Weight (base: g)
    'mg': 0.001, 'g': 1.0, 'kg': 1000.0, 'lb': 453.592, 'oz': 28.3495,
    // Volume (base: ml)
    'ml': 1.0, 'l': 1000.0, 'tsp': 4.92892, 'tbsp': 14.7868,
    'fl oz': 29.5735, 'cup': 236.588, 'pt': 473.176, 'qt': 946.353,
    'gal': 3785.41,
    // Data size (base: B)
    'B': 1.0, 'KB': 1024.0, 'MB': 1048576.0, 'GB': 1073741824.0,
    'TB': 1099511627776.0,
    // Time duration (base: ms)
    'ms': 1.0, 's': 1000.0, 'min': 60000.0, 'hr': 3600000.0,
    'day': 86400000.0, 'week': 604800000.0,
    // Temperature handled separately (non-linear)
  };

  // Canonical unit name → category
  static const Map<String, UnitCategory> _unitToCategory = {
    'mm': UnitCategory.length, 'cm': UnitCategory.length,
    'm': UnitCategory.length, 'km': UnitCategory.length,
    'in': UnitCategory.length, 'ft': UnitCategory.length,
    'yd': UnitCategory.length, 'mi': UnitCategory.length,
    'mg': UnitCategory.weight, 'g': UnitCategory.weight,
    'kg': UnitCategory.weight, 'lb': UnitCategory.weight,
    'oz': UnitCategory.weight,
    'C': UnitCategory.temperature, 'F': UnitCategory.temperature,
    'K': UnitCategory.temperature,
    'ml': UnitCategory.volume, 'l': UnitCategory.volume,
    'tsp': UnitCategory.volume, 'tbsp': UnitCategory.volume,
    'fl oz': UnitCategory.volume, 'cup': UnitCategory.volume,
    'pt': UnitCategory.volume, 'qt': UnitCategory.volume,
    'gal': UnitCategory.volume,
    'B': UnitCategory.dataSize, 'KB': UnitCategory.dataSize,
    'MB': UnitCategory.dataSize, 'GB': UnitCategory.dataSize,
    'TB': UnitCategory.dataSize,
    'ms': UnitCategory.timeDuration, 's': UnitCategory.timeDuration,
    'min': UnitCategory.timeDuration, 'hr': UnitCategory.timeDuration,
    'day': UnitCategory.timeDuration, 'week': UnitCategory.timeDuration,
  };

  // Display order of units per category (controls card row order)
  static const Map<UnitCategory, List<String>> _categoryUnits = {
    UnitCategory.length: ['mm', 'cm', 'm', 'km', 'in', 'ft', 'yd', 'mi'],
    UnitCategory.weight: ['mg', 'g', 'kg', 'lb', 'oz'],
    UnitCategory.temperature: ['C', 'F', 'K'],
    UnitCategory.volume: ['ml', 'l', 'tsp', 'tbsp', 'fl oz', 'cup', 'pt', 'qt', 'gal'],
    UnitCategory.dataSize: ['B', 'KB', 'MB', 'GB', 'TB'],
    UnitCategory.timeDuration: ['ms', 's', 'min', 'hr', 'day', 'week'],
  };

  // Maps lowercased user input to canonical unit names
  static const Map<String, String> _unitAliases = {
    // Length
    'mm': 'mm', 'cm': 'cm', 'm': 'm', 'km': 'km',
    'in': 'in', 'ft': 'ft', 'yd': 'yd', 'mi': 'mi',
    'inch': 'in', 'inches': 'in', 'feet': 'ft', 'foot': 'ft',
    'yard': 'yd', 'yards': 'yd', 'mile': 'mi', 'miles': 'mi',
    'meter': 'm', 'meters': 'm', 'metre': 'm', 'metres': 'm',
    'kilometer': 'km', 'kilometers': 'km', 'kilometre': 'km',
    // Weight
    'mg': 'mg', 'g': 'g', 'kg': 'kg', 'lb': 'lb', 'oz': 'oz',
    'lbs': 'lb', 'gram': 'g', 'grams': 'g',
    'kilogram': 'kg', 'kilograms': 'kg',
    'pound': 'lb', 'pounds': 'lb', 'ounce': 'oz', 'ounces': 'oz',
    // Temperature
    'c': 'C', '°c': 'C', 'celsius': 'C',
    'f': 'F', '°f': 'F', 'fahrenheit': 'F',
    'k': 'K', 'kelvin': 'K',
    // Volume
    'ml': 'ml', 'l': 'l', 'tsp': 'tsp', 'tbsp': 'tbsp',
    'fl oz': 'fl oz', 'floz': 'fl oz', 'cup': 'cup', 'cups': 'cup',
    'pt': 'pt', 'qt': 'qt', 'gal': 'gal',
    'liter': 'l', 'liters': 'l', 'litre': 'l', 'litres': 'l',
    'milliliter': 'ml', 'milliliters': 'ml',
    'teaspoon': 'tsp', 'teaspoons': 'tsp',
    'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
    'pint': 'pt', 'pints': 'pt', 'quart': 'qt', 'quarts': 'qt',
    'gallon': 'gal', 'gallons': 'gal',
    // Data size
    'b': 'B', 'kb': 'KB', 'mb': 'MB', 'gb': 'GB', 'tb': 'TB',
    'byte': 'B', 'bytes': 'B',
    'kilobyte': 'KB', 'kilobytes': 'KB',
    'megabyte': 'MB', 'megabytes': 'MB',
    'gigabyte': 'GB', 'gigabytes': 'GB',
    'terabyte': 'TB', 'terabytes': 'TB',
    // Time duration
    'ms': 'ms', 'millisecond': 'ms', 'milliseconds': 'ms',
    's': 's', 'sec': 's', 'second': 's', 'seconds': 's',
    'min': 'min', 'minute': 'min', 'minutes': 'min',
    'hr': 'hr', 'hour': 'hr', 'hours': 'hr',
    'day': 'day', 'days': 'day',
    'week': 'week', 'weeks': 'week',
  };

  static Map<String, double> _convertInCategory(
    double value,
    String canonicalUnit,
    UnitCategory category,
  ) {
    if (category == UnitCategory.temperature) {
      return _convertTemperature(value, canonicalUnit);
    }
    final units = _categoryUnits[category]!;
    final fromFactor = _conversionFactors[canonicalUnit]!;
    final baseValue = value * fromFactor;
    return {for (final u in units) u: baseValue / _conversionFactors[u]!};
  }

  static Map<String, double> _convertTemperature(
    double value,
    String fromUnit,
  ) {
    final double celsius;
    switch (fromUnit) {
      case 'C':
        celsius = value;
      case 'F':
        celsius = (value - 32) * 5 / 9;
      case 'K':
        celsius = value - 273.15;
      default:
        celsius = value;
    }
    return {
      'C': celsius,
      'F': celsius * 9 / 5 + 32,
      'K': celsius + 273.15,
    };
  }

  static UnitParseResult _parseUnitConversion(String input) {
    final match = _valueUnitRegex.firstMatch(input);
    if (match == null) {
      return const UnitParseResult(
        isSuccess: false,
        category: UnitCategory.unknown,
        errorMessage:
            'Enter a value with a unit (e.g. 100km, 5GB, 98.6°F, 1hr)',
      );
    }

    final value = double.tryParse(match.group(1)!);
    if (value == null) {
      return const UnitParseResult(
        isSuccess: false,
        category: UnitCategory.unknown,
        errorMessage: 'Invalid number format',
      );
    }

    final unitStr = match.group(2)!.trim().toLowerCase();
    final canonical = _unitAliases[unitStr];
    if (canonical == null) {
      return UnitParseResult(
        isSuccess: false,
        category: UnitCategory.unknown,
        errorMessage:
            'Unknown unit "$unitStr". Try: mm, cm, m, km, ft, mi, '
            'kg, lb, °C, °F, K, ml, l, cup, gal, B, KB, MB, GB, TB, '
            'ms, s, min, hr, day, week',
      );
    }

    final category = _unitToCategory[canonical]!;
    final conversions = _convertInCategory(value, canonical, category);

    return UnitParseResult(
      isSuccess: true,
      category: category,
      fromValue: value,
      fromUnit: canonical,
      conversions: conversions,
    );
  }

  static UnitParseResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return UnitParseResult.empty;

    // Skip encoding check for pure integers — likely timestamps, not hex
    final isPureInteger = RegExp(r'^-?\d+$').hasMatch(trimmed);

    // Check for recognized unit keyword first — prevents inputs like "0C" or
    // "1cup" from being misidentified as base64 before unit lookup.
    if (!isPureInteger) {
      final match = _valueUnitRegex.firstMatch(trimmed);
      if (match != null) {
        final unitStr = match.group(2)!.trim().toLowerCase();
        if (_unitAliases.containsKey(unitStr)) {
          return _parseUnitConversion(trimmed);
        }
      }
    }

    if (!isPureInteger) {
      final encodingResult = EncodingParser.detectAndConvert(trimmed);
      if (encodingResult.isSuccess) {
        return UnitParseResult(
          isSuccess: true,
          category: UnitCategory.encoding,
          encodingResult: encodingResult,
        );
      }
    }

    final tsResult = TimestampParser.parseAnyFormat(trimmed);
    if (tsResult.isSuccess) {
      return UnitParseResult(
        isSuccess: true,
        category: UnitCategory.timestamp,
        timestamp: tsResult.timestamp,
      );
    }

    return _parseUnitConversion(trimmed);
  }
}
