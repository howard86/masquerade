# Unit Converter Screen Design

**Date:** 2026-03-27
**Status:** Approved

## Overview

Add a unified unit converter screen to Masquerade, restructure the app to use a two-tab layout, and absorb the existing timestamp and encoding tools into the converter. The first tab becomes a Tools Hub that serves as a visual directory for all available tools.

## Navigation Architecture

Replace the single-screen `CupertinoApp` home with a `CupertinoTabScaffold` containing two tabs:

- **Tab 1 — Tools Hub** (house icon): Visual directory of available tools
- **Tab 2 — Unit Converter** (arrow swap icon): Unified conversion tool

`ResponsiveLayout` wraps the entire `CupertinoTabScaffold` so the device frame preview still works on large screens. A shared `CupertinoTabController` is passed down so the Tools Hub can switch to Tab 2 programmatically when a card is tapped.

`app.dart` is refactored: the `home` property changes from `ResponsiveLayout(child: MyHomePage(...))` to `ResponsiveLayout(child: MasqueradeTabScaffold())`.

## Tools Hub (`lib/tools_hub_page.dart`)

A `CupertinoPageScaffold` with large title "Tools" and a scrollable list of tool cards. Each card displays an icon, name, and one-line description. Tapping switches to the corresponding tab via the shared `CupertinoTabController`.

Initial cards:
| Icon | Name | Description |
|------|------|-------------|
| `arrow.2.squarepath` | Unit Converter | Convert units, timestamps & encodings |

No navigation push — the tab bar is the navigation layer. The hub scales as new tools are added.

## Unit Converter Screen (`lib/unit_converter_page.dart`)

Mirrors `MyHomePage` in structure and visual style:

- Large title: "Converter"
- `CupertinoTextField` with placeholder: `"Enter value with unit (e.g. 100km, 5GB, 98.6F, 1714000000)"`
- 200ms debounced parse on every keystroke
- Results displayed below the input field
- Error banner (red, same pattern as existing screen) when input is unrecognized
- Clear button pinned at bottom

The screen is a thin controller: it calls `UnitParser.parse(input)` and routes the result to the appropriate display widget based on detected category. Timestamp and encoding inputs delegate to the existing parsers and render with existing display cards.

## Parser (`lib/utils/unit_parser.dart`)

`UnitParser.parse(String input)` → `UnitParseResult`

Detection priority (applied in order):
1. **Encoding** — if input matches Base64 or Hex patterns, delegate to `EncodingParser`
2. **Timestamp** — if input is a pure integer or ISO 8601 string, delegate to `TimestampParser`
3. **Unit conversion** — scan for a known unit keyword (case-insensitive) to identify category

`UnitParseResult` fields:
- `isSuccess: bool`
- `category: UnitCategory` (enum)
- `fromValue: double`
- `fromUnit: String`
- `conversions: Map<String, double>` — all units in the category with converted values
- `errorMessage: String?`

### Supported Categories and Units

| Category | Units |
|----------|-------|
| Length | mm, cm, m, km, in, ft, yd, mi |
| Weight | mg, g, kg, lb, oz |
| Temperature | °C / C, °F / F, K |
| Volume | ml, l, tsp, tbsp, fl oz, cup, pt, qt, gal |
| Data Size | B, KB, MB, GB, TB |
| Time Duration | ms, s, min, hr, day, week |
| Timestamp | delegates to `TimestampParser` |
| Encoding | delegates to `EncodingParser` |

Ambiguous bare numbers with no unit keyword return `isSuccess = false` with an error listing supported formats.

## Display Widget (`lib/widgets/unit_conversion_display_card.dart`)

Used for the 6 native unit categories (length, weight, temperature, volume, data size, time duration). Shows:
- Category label at top (e.g., "Length")
- One row per target unit: unit name on the left, converted value on the right
- Tap-to-copy on each row (same `CopyUtil` pattern as existing rows)

Timestamp inputs continue to render via `TimestampDisplayCard`. Encoding inputs continue to render via `EncodingDisplayCard`. The converter screen conditionally renders the correct widget based on `UnitParseResult.category`.

## Error Handling

| Input | Behavior |
|-------|----------|
| Empty | Clear all state, no error shown |
| Bare number (no unit) | Error banner: "Add a unit (e.g. 100km, 5GB)" |
| Unrecognized unit keyword | Error banner with supported format list |
| Out-of-range values | Display result as-is (no clamping) |
| Temperature below absolute zero | Show result; no special validation |

## File Structure

```
lib/
  app.dart                          # refactored: CupertinoTabScaffold
  tools_hub_page.dart               # new: Tab 1
  unit_converter_page.dart          # new: Tab 2
  home_page.dart                    # removed (absorbed into unit_converter_page)
  utils/
    unit_parser.dart                # new
    timestamp_parser.dart           # unchanged
    encoding_parser.dart            # unchanged
    copy_util.dart                  # unchanged
  widgets/
    unit_conversion_display_card.dart  # new
    timestamp_display_card.dart     # unchanged
    encoding_display_card.dart      # unchanged
    timestamp_row.dart              # unchanged
    encoding_value_row.dart         # unchanged
    iphone_frame.dart               # unchanged
test/
  utils/
    unit_parser_test.dart           # new
    timestamp_parser_test.dart      # unchanged
  widgets/
    unit_conversion_display_card_test.dart  # new
    iphone_frame_test.dart          # unchanged
```

## Testing

- `unit_parser_test.dart`: unit tests for each category, delegation to existing parsers, error cases, case-insensitive unit matching, ambiguous input handling
- `unit_conversion_display_card_test.dart`: widget test verifying rows render correctly for a sample result
- Existing tests remain unchanged
