import 'package:flutter/painting.dart';

/// Magic Box type scale. Mirrors `MB_TOKENS.type` exactly.
/// Sans = SF Pro stack. Mono = SF Mono stack with tabular numerals.
class MBTextStyles {
  const MBTextStyles._();

  static const String sansFamily = '.SF Pro Text';
  static const List<String> sansFallback = <String>[
    'SF Pro Text',
    'SF Pro Display',
    'system-ui',
    '-apple-system',
  ];

  static const String monoFamily = 'SF Mono';
  static const List<String> monoFallback = <String>[
    'SFMono-Regular',
    'JetBrains Mono',
    'Berkeley Mono',
    'Menlo',
    'monospace',
  ];

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle _sans({
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
  }) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: fs,
    height: lh / fs,
    fontWeight: fw,
    letterSpacing: tr,
  );

  static TextStyle _mono({
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: fs,
    height: lh / fs,
    fontWeight: fw,
    letterSpacing: tr,
    fontFeatures: _tabularFigures,
  );

  static final TextStyle largeTitle = _sans(
    fs: 34,
    lh: 41,
    fw: FontWeight.w700,
    tr: 0.4,
  );
  static final TextStyle title1 = _sans(
    fs: 28,
    lh: 34,
    fw: FontWeight.w700,
    tr: 0.36,
  );
  static final TextStyle title2 = _sans(
    fs: 22,
    lh: 28,
    fw: FontWeight.w700,
    tr: 0.35,
  );
  static final TextStyle title3 = _sans(
    fs: 20,
    lh: 25,
    fw: FontWeight.w600,
    tr: 0.38,
  );
  static final TextStyle headline = _sans(
    fs: 17,
    lh: 22,
    fw: FontWeight.w600,
    tr: -0.43,
  );
  static final TextStyle body = _sans(
    fs: 17,
    lh: 22,
    fw: FontWeight.w400,
    tr: -0.43,
  );
  static final TextStyle callout = _sans(
    fs: 16,
    lh: 21,
    fw: FontWeight.w400,
    tr: -0.32,
  );
  static final TextStyle subhead = _sans(
    fs: 15,
    lh: 20,
    fw: FontWeight.w400,
    tr: -0.24,
  );
  static final TextStyle footnote = _sans(
    fs: 13,
    lh: 18,
    fw: FontWeight.w400,
    tr: -0.08,
  );
  static final TextStyle caption1 = _sans(
    fs: 12,
    lh: 16,
    fw: FontWeight.w400,
    tr: 0,
  );
  static final TextStyle caption2 = _sans(
    fs: 11,
    lh: 13,
    fw: FontWeight.w500,
    tr: 0.07,
  );

  // Mono — JSX uses 450 (non-standard); rounded to 500.
  static final TextStyle monoXl = _mono(
    fs: 28,
    lh: 34,
    fw: FontWeight.w500,
    tr: -0.5,
  );
  static final TextStyle monoLg = _mono(
    fs: 20,
    lh: 26,
    fw: FontWeight.w500,
    tr: -0.3,
  );
  static final TextStyle monoMd = _mono(
    fs: 15,
    lh: 22,
    fw: FontWeight.w500,
    tr: 0,
  );
  static final TextStyle monoSm = _mono(
    fs: 13,
    lh: 18,
    fw: FontWeight.w500,
    tr: 0,
  );

  /// Uppercase section-label style (caption2 + tracking + 600 weight).
  static final TextStyle sectionLabel = _sans(
    fs: 11,
    lh: 13,
    fw: FontWeight.w600,
    tr: 0.6,
  );
}
