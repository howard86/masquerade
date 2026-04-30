# Unit Converter Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-tab app structure with a Tools Hub (Tab 1) and a unified Unit Converter screen (Tab 2) that handles length, weight, temperature, volume, data size, time duration, timestamp, and encoding conversions — then delete the now-redundant home screen.

**Architecture:** A new `UnitParser` mirrors `TimestampParser` in design: a static `parse()` method that detects input type and returns a `UnitParseResult`. The converter screen (`UnitConverterPage`) is a thin controller that calls `UnitParser.parse()` and routes results to the correct display card. `app.dart` is refactored to a `CupertinoTabScaffold` with two tabs. `home_page.dart` is deleted.

**Tech Stack:** Flutter/Dart, Cupertino widgets, `intl` (already a dependency), existing `TimestampParser`, `EncodingParser`, `CopyToClipboardUtil`.

**Worktree:** `.worktrees/unit-converter-screen` (branch: `feature/unit-converter-screen`) — all work should be done here.

**OpenSpec artifacts:** `openspec/changes/unit-converter-screen/` — proposal, design, specs (unit-conversion, tools-hub, unit-converter-screen), tasks.

---

### Task 1: UnitParser — data model (enum + result class)

**Files:**
- Create: `lib/utils/unit_parser.dart`
- Create: `test/utils/unit_parser_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/utils/unit_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/unit_parser.dart';

void main() {
  group('UnitParseResult', () {
    test('empty result has isSuccess false and unknown category', () {
      const result = UnitParseResult.empty;
      expect(result.isSuccess, isFalse);
      expect(result.category, UnitCategory.unknown);
      expect(result.errorMessage, isNull);
      expect(result.conversions, isEmpty);
    });

    test('successful result carries conversions', () {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.length,
        fromValue: 1.0,
        fromUnit: 'm',
        conversions: {'km': 0.001, 'mm': 1000.0},
      );
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.length);
      expect(result.fromValue, 1.0);
      expect(result.fromUnit, 'm');
      expect(result.conversions['km'], 0.001);
      expect(result.conversions['mm'], 1000.0);
    });

    test('error result carries errorMessage', () {
      const result = UnitParseResult(
        isSuccess: false,
        category: UnitCategory.unknown,
        errorMessage: 'Unknown unit',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Unknown unit');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/utils/unit_parser_test.dart
```

Expected: FAIL — `unit_parser.dart` does not exist yet.

- [ ] **Step 3: Implement the data model**

Create `lib/utils/unit_parser.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/utils/unit_parser_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/unit_parser.dart test/utils/unit_parser_test.dart
git commit -m "feat: add UnitParseResult data model and UnitCategory enum"
```

---

### Task 2: UnitParser — conversion tables and native unit math

**Files:**
- Modify: `lib/utils/unit_parser.dart`
- Modify: `test/utils/unit_parser_test.dart`

- [ ] **Step 1: Add failing tests for each category**

Append to the `main()` in `test/utils/unit_parser_test.dart` (inside the existing `group` or as a new top-level `group`):

```dart
  group('UnitParser._parseUnitConversion (via parse)', () {
    group('length', () {
      test('converts 1 m to all length units', () {
        final result = UnitParser.parse('1m');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.length);
        expect(result.fromUnit, 'm');
        expect(result.conversions['mm'], closeTo(1000.0, 0.001));
        expect(result.conversions['cm'], closeTo(100.0, 0.001));
        expect(result.conversions['km'], closeTo(0.001, 0.000001));
        expect(result.conversions['ft'], closeTo(3.28084, 0.0001));
        expect(result.conversions['mi'], closeTo(0.000621371, 0.0000001));
      });

      test('converts 1 km to meters', () {
        final result = UnitParser.parse('1km');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['m'], closeTo(1000.0, 0.001));
      });

      test('is case-insensitive for unit', () {
        final result = UnitParser.parse('1KM');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.length);
      });

      test('handles space between value and unit', () {
        final result = UnitParser.parse('100 km');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['m'], closeTo(100000.0, 0.001));
      });
    });

    group('weight', () {
      test('converts 1 kg to all weight units', () {
        final result = UnitParser.parse('1kg');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.weight);
        expect(result.conversions['g'], closeTo(1000.0, 0.001));
        expect(result.conversions['lb'], closeTo(2.20462, 0.0001));
        expect(result.conversions['oz'], closeTo(35.274, 0.001));
      });
    });

    group('temperature', () {
      test('converts 0 C to F and K', () {
        final result = UnitParser.parse('0C');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.temperature);
        expect(result.conversions['F'], closeTo(32.0, 0.001));
        expect(result.conversions['K'], closeTo(273.15, 0.001));
      });

      test('converts 100 C to F', () {
        final result = UnitParser.parse('100C');
        expect(result.conversions['F'], closeTo(212.0, 0.001));
      });

      test('converts -40 F to C (crossover point)', () {
        final result = UnitParser.parse('-40F');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['C'], closeTo(-40.0, 0.001));
      });

      test('converts 300 K to C', () {
        final result = UnitParser.parse('300K');
        expect(result.conversions['C'], closeTo(26.85, 0.01));
      });
    });

    group('volume', () {
      test('converts 1 l to ml', () {
        final result = UnitParser.parse('1l');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.volume);
        expect(result.conversions['ml'], closeTo(1000.0, 0.001));
      });

      test('converts 1 cup to ml', () {
        final result = UnitParser.parse('1cup');
        expect(result.isSuccess, isTrue);
        expect(result.conversions['ml'], closeTo(236.588, 0.001));
      });
    });

    group('data size', () {
      test('converts 1 GB to MB and KB', () {
        final result = UnitParser.parse('1GB');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.dataSize);
        expect(result.conversions['MB'], closeTo(1024.0, 0.001));
        expect(result.conversions['KB'], closeTo(1048576.0, 0.001));
      });

      test('converts 1 TB to GB', () {
        final result = UnitParser.parse('1TB');
        expect(result.conversions['GB'], closeTo(1024.0, 0.001));
      });
    });

    group('time duration', () {
      test('converts 1 hr to minutes and seconds', () {
        final result = UnitParser.parse('1hr');
        expect(result.isSuccess, isTrue);
        expect(result.category, UnitCategory.timeDuration);
        expect(result.conversions['min'], closeTo(60.0, 0.001));
        expect(result.conversions['s'], closeTo(3600.0, 0.001));
        expect(result.conversions['ms'], closeTo(3600000.0, 0.001));
      });

      test('converts 1 week to days', () {
        final result = UnitParser.parse('1week');
        expect(result.conversions['day'], closeTo(7.0, 0.001));
      });
    });

    group('error cases', () {
      test('returns failure for empty input', () {
        final result = UnitParser.parse('');
        expect(result.isSuccess, isFalse);
        expect(result.category, UnitCategory.unknown);
      });

      test('returns failure for unknown unit', () {
        final result = UnitParser.parse('100xyz');
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('returns failure for bare number with no unit', () {
        // Pure integers are handled as timestamps, not unit errors
        // But a float with no unit should fail unit conversion
        final result = UnitParser.parse('3.14');
        expect(result.isSuccess, isFalse);
      });
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/utils/unit_parser_test.dart
```

Expected: FAIL — `UnitParser` class does not exist yet.

- [ ] **Step 3: Implement the conversion logic**

Append to `lib/utils/unit_parser.dart` (after the `UnitParseResult` class):

```dart
import 'package:masquerade/utils/timestamp_parser.dart';

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
```

Note: Add the `TimestampParser` import at the top of `unit_parser.dart` (alongside the existing `EncodingParser` import):

```dart
import 'package:masquerade/utils/encoding_parser.dart';
import 'package:masquerade/utils/timestamp_parser.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/utils/unit_parser_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/unit_parser.dart test/utils/unit_parser_test.dart
git commit -m "feat: implement UnitParser with conversion logic for all six categories"
```

---

### Task 3: UnitParser — delegation tests (encoding, timestamp)

**Files:**
- Modify: `test/utils/unit_parser_test.dart`

- [ ] **Step 1: Add failing delegation tests**

Append inside `main()` in `test/utils/unit_parser_test.dart`:

```dart
  group('UnitParser.parse — encoding delegation', () {
    test('detects base64 and sets encoding category', () {
      // "aGVsbG8=" is base64 for "hello"
      final result = UnitParser.parse('aGVsbG8=');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.encoding);
      expect(result.encodingResult, isNotNull);
      expect(result.encodingResult!.type, EncodingType.base64);
    });

    test('detects hex string and sets encoding category', () {
      // "68656c6c6f" is hex for "hello"
      final result = UnitParser.parse('68656c6c6f');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.encoding);
      expect(result.encodingResult!.type, EncodingType.hex);
    });
  });

  group('UnitParser.parse — timestamp delegation', () {
    test('detects Unix timestamp (pure integer)', () {
      final result = UnitParser.parse('1672531200');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.timestamp);
      expect(result.timestamp, isNotNull);
      expect(result.timestamp!.year, 2023);
    });

    test('detects ISO 8601 date string', () {
      final result = UnitParser.parse('2023-11-14T22:13:20Z');
      expect(result.isSuccess, isTrue);
      expect(result.category, UnitCategory.timestamp);
      expect(result.timestamp!.year, 2023);
    });

    test('pure integer is not treated as hex', () {
      // "1714000000" contains only 0-9 chars (valid hex chars)
      // but should be treated as a timestamp, not encoding
      final result = UnitParser.parse('1714000000');
      expect(result.category, UnitCategory.timestamp);
    });
  });
```

Add the `EncodingType` import to the test file:

```dart
import 'package:masquerade/utils/encoding_parser.dart';
```

- [ ] **Step 2: Run tests to verify they pass (no new code needed)**

```bash
flutter test test/utils/unit_parser_test.dart
```

Expected: All tests PASS (delegation already implemented in Task 2 `parse()`).

- [ ] **Step 3: Commit**

```bash
git add test/utils/unit_parser_test.dart
git commit -m "test: add delegation tests for UnitParser encoding and timestamp"
```

---

### Task 4: UnitConversionDisplayCard widget

**Files:**
- Create: `lib/widgets/unit_conversion_display_card.dart`
- Create: `test/widgets/unit_conversion_display_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/unit_conversion_display_card_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/unit_parser.dart';
import 'package:masquerade/widgets/unit_conversion_display_card.dart';

void main() {
  group('UnitConversionDisplayCard', () {
    testWidgets('renders category label', (tester) async {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.length,
        fromValue: 1.0,
        fromUnit: 'm',
        conversions: {
          'mm': 1000.0,
          'cm': 100.0,
          'm': 1.0,
          'km': 0.001,
          'in': 39.3701,
          'ft': 3.28084,
          'yd': 1.09361,
          'mi': 0.000621371,
        },
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: UnitConversionDisplayCard(result: result),
            ),
          ),
        ),
      );

      expect(find.text('Length'), findsOneWidget);
    });

    testWidgets('renders a row for each unit', (tester) async {
      const result = UnitParseResult(
        isSuccess: true,
        category: UnitCategory.weight,
        fromValue: 1.0,
        fromUnit: 'kg',
        conversions: {
          'mg': 1000000.0,
          'g': 1000.0,
          'kg': 1.0,
          'lb': 2.20462,
          'oz': 35.274,
        },
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: UnitConversionDisplayCard(result: result),
            ),
          ),
        ),
      );

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
      expect(find.text('lb'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/unit_conversion_display_card_test.dart
```

Expected: FAIL — widget file does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/unit_conversion_display_card.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/widgets/unit_conversion_display_card_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/unit_conversion_display_card.dart test/widgets/unit_conversion_display_card_test.dart
git commit -m "feat: add UnitConversionDisplayCard widget"
```

---

### Task 5: UnitConverterPage screen

**Files:**
- Create: `lib/unit_converter_page.dart`

- [ ] **Step 1: Implement the page**

Create `lib/unit_converter_page.dart`:

```dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:masquerade/utils/unit_parser.dart';
import 'package:masquerade/widgets/unit_conversion_display_card.dart';
import 'package:masquerade/widgets/timestamp_display_card.dart';
import 'package:masquerade/widgets/encoding_display_card.dart';

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  final TextEditingController _inputController = TextEditingController();
  UnitParseResult? _result;
  Timer? _debounceTimer;

  void _parseDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), _parse);
  }

  void _parse() {
    final input = _inputController.text.trim();
    setState(() {
      _result = input.isEmpty ? null : UnitParser.parse(input);
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _inputController.clear();
    setState(() => _result = null);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Converter',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navLargeTitleTextStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Units, Timestamps & Encodings',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 15,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      CupertinoTextField(
                        controller: _inputController,
                        placeholder:
                            'Enter value with unit (e.g. 100km, 5GB, 98.6°F)',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            CupertinoIcons.arrow_2_squarepath,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                            width: 0.5,
                          ),
                        ),
                        onChanged: (_) => _parseDebounced(),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      if (_result != null) ...[
                        if (!_result!.isSuccess)
                          _ErrorBanner(message: _result!.errorMessage ?? 'Invalid input'),
                        if (_result!.isSuccess)
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: _buildResultCard(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _clear,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.clear_circled_solid),
                      SizedBox(width: 8),
                      Text('Clear'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    switch (r.category) {
      case UnitCategory.timestamp:
        return TimestampDisplayCard(timestamp: r.timestamp!);
      case UnitCategory.encoding:
        return EncodingDisplayCard(
          originalValue: r.encodingResult!.original,
          encodingType: r.encodingResult!.type.name,
          decodedValue: r.encodingResult!.result!,
        );
      default:
        return UnitConversionDisplayCard(result: r);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed.withOpacity(0.1),
          border: Border.all(
            color: CupertinoColors.systemRed.withOpacity(0.3),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: CupertinoColors.systemRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.systemRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run the full test suite to confirm nothing broke**

```bash
flutter test
```

Expected: All existing tests PASS. (No new test for this page — logic is covered by `unit_parser_test.dart`.)

- [ ] **Step 3: Commit**

```bash
git add lib/unit_converter_page.dart
git commit -m "feat: add UnitConverterPage screen"
```

---

### Task 6: ToolsHubPage screen

**Files:**
- Create: `lib/tools_hub_page.dart`

- [ ] **Step 1: Implement the page**

Create `lib/tools_hub_page.dart`:

```dart
import 'package:flutter/cupertino.dart';

class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({super.key, required this.onToolSelected});

  /// Called with the tab index to switch to when a tool card is tapped.
  final void Function(int tabIndex) onToolSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Tools',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _ToolCard(
                icon: CupertinoIcons.arrow_2_squarepath,
                name: 'Unit Converter',
                description: 'Convert units, timestamps & encodings',
                onTap: () => onToolSelected(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.name,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CupertinoColors.systemBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run the full test suite**

```bash
flutter test
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/tools_hub_page.dart
git commit -m "feat: add ToolsHubPage with tool card list"
```

---

### Task 7: Refactor app.dart to CupertinoTabScaffold

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Replace app.dart**

Replace the entire contents of `lib/app.dart` with:

```dart
import 'package:flutter/cupertino.dart';
import 'package:masquerade/tools_hub_page.dart';
import 'package:masquerade/unit_converter_page.dart';
import 'package:masquerade/widgets/iphone_frame.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Masquerade - Utility Toolbox',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.label,
          textStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          actionTextStyle: TextStyle(
            color: CupertinoColors.systemBlue,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          tabLabelTextStyle: TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.24,
          ),
          navTitleTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.41,
          ),
          navActionTextStyle: TextStyle(
            color: CupertinoColors.systemBlue,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          pickerTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 21,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          dateTimePickerTextStyle: TextStyle(
            color: CupertinoColors.label,
            fontSize: 21,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
        ),
      ),
      home: const ResponsiveLayout(child: _MasqueradeTabScaffold()),
    );
  }
}

class _MasqueradeTabScaffold extends StatefulWidget {
  const _MasqueradeTabScaffold();

  @override
  State<_MasqueradeTabScaffold> createState() =>
      _MasqueradeTabScaffoldState();
}

class _MasqueradeTabScaffoldState extends State<_MasqueradeTabScaffold> {
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.arrow_2_squarepath),
            label: 'Converter',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return ToolsHubPage(
              onToolSelected: (i) => _tabController.index = i,
            );
          case 1:
            return const UnitConverterPage();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
```

- [ ] **Step 2: Run the full test suite**

```bash
flutter test
```

Expected: All tests PASS (existing widget_test.dart may fail if it imports `MyHomePage` — that will be fixed in Task 8).

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart
git commit -m "feat: refactor app.dart to CupertinoTabScaffold with Tools Hub and Converter tabs"
```

---

### Task 8: Cleanup — delete home_page.dart, replace widget_test.dart

**Files:**
- Delete: `lib/home_page.dart`
- Replace: `test/widget_test.dart`

- [ ] **Step 1: Delete home_page.dart**

```bash
git rm lib/home_page.dart
```

- [ ] **Step 2: Replace widget_test.dart**

Replace the entire contents of `test/widget_test.dart` with:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';

void main() {
  testWidgets('app renders two-tab scaffold', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Converter'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the full test suite to confirm everything passes**

```bash
flutter test
```

Expected: All tests PASS. No references to `MyHomePage` should remain.

- [ ] **Step 4: Verify no dead references remain**

```bash
grep -r "MyHomePage\|home_page" lib/ test/
```

Expected: No output (zero matches).

- [ ] **Step 5: Commit**

```bash
git add test/widget_test.dart && git commit -m "cleanup: delete home_page.dart and replace widget smoke test"
```
