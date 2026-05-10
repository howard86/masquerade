import 'package:flutter/painting.dart';

/// Masquerade type scale. Display + nav titles in IBM Plex Serif, body in
/// IBM Plex Sans, code in IBM Plex Mono with tabular figures.
class MqTextStyles {
  const MqTextStyles._();

  static const String serifFamily = 'IBMPlexSerif';
  static const String sansFamily = 'IBMPlexSans';
  static const String monoFamily = 'IBMPlexMono';

  /// Empty fallback: Plex is bundled, fallback only kicks in if asset load
  /// fails. Kept as a non-null public constant so callers (chip, mono cell)
  /// can pass it through copyWith without conditional logic.
  static const List<String> sansFallback = <String>[];
  static const List<String> serifFallback = <String>[];
  static const List<String> monoFallback = <String>[];

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle _style({
    required String family,
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
    List<FontFeature>? features,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fs,
    height: lh / fs,
    fontWeight: fw,
    letterSpacing: tr,
    fontFeatures: features,
  );

  static TextStyle _sans({
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
  }) => _style(family: sansFamily, fs: fs, lh: lh, fw: fw, tr: tr);

  static TextStyle _serif({
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
  }) => _style(family: serifFamily, fs: fs, lh: lh, fw: fw, tr: tr);

  static TextStyle _mono({
    required double fs,
    required double lh,
    required FontWeight fw,
    required double tr,
  }) => _style(
    family: monoFamily,
    fs: fs,
    lh: lh,
    fw: fw,
    tr: tr,
    features: _tabularFigures,
  );

  /// Editorial display tier — Plex Serif. Reserved for masthead + tool hero.
  static final TextStyle display = _serif(
    fs: 48,
    lh: 56,
    fw: FontWeight.w600,
    tr: -0.5,
  );

  static final TextStyle largeTitle = _serif(
    fs: 34,
    lh: 41,
    fw: FontWeight.w600,
    tr: 0.2,
  );
  static final TextStyle title1 = _sans(
    fs: 28,
    lh: 34,
    fw: FontWeight.w600,
    tr: 0.2,
  );
  static final TextStyle title2 = _sans(
    fs: 22,
    lh: 28,
    fw: FontWeight.w600,
    tr: 0.2,
  );
  static final TextStyle title3 = _sans(
    fs: 20,
    lh: 26,
    fw: FontWeight.w600,
    tr: 0.2,
  );
  static final TextStyle headline = _sans(
    fs: 17,
    lh: 22,
    fw: FontWeight.w600,
    tr: -0.2,
  );
  static final TextStyle body = _sans(
    fs: 17,
    lh: 24,
    fw: FontWeight.w400,
    tr: -0.2,
  );
  static final TextStyle callout = _sans(
    fs: 16,
    lh: 22,
    fw: FontWeight.w400,
    tr: -0.15,
  );
  static final TextStyle subhead = _sans(
    fs: 15,
    lh: 20,
    fw: FontWeight.w400,
    tr: -0.1,
  );
  static final TextStyle footnote = _sans(
    fs: 13,
    lh: 18,
    fw: FontWeight.w400,
    tr: 0,
  );
  static final TextStyle caption1 = _sans(
    fs: 12,
    lh: 16,
    fw: FontWeight.w400,
    tr: 0,
  );
  static final TextStyle caption2 = _sans(
    fs: 11,
    lh: 14,
    fw: FontWeight.w500,
    tr: 0.1,
  );

  static final TextStyle monoXl = _mono(
    fs: 28,
    lh: 36,
    fw: FontWeight.w500,
    tr: 0,
  );
  static final TextStyle monoLg = _mono(
    fs: 20,
    lh: 28,
    fw: FontWeight.w500,
    tr: 0,
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
    lh: 14,
    fw: FontWeight.w600,
    tr: 0.6,
  );
}
