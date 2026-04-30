import 'package:flutter/cupertino.dart';

import 'mb_colors.dart';
import 'mb_typography.dart';

/// Bundle of Magic Box tokens for a single mode. Resolved via [MBTheme.of].
@immutable
class MBTokens {
  const MBTokens({required this.colors, required this.brightness});
  final MBColors colors;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;
}

/// Inherited bridge that exposes [MBTokens] beneath a [CupertinoApp].
class MBTheme extends InheritedWidget {
  const MBTheme({super.key, required this.tokens, required super.child});

  final MBTokens tokens;

  static MBTokens of(BuildContext context) {
    final MBTheme? scope = context
        .dependOnInheritedWidgetOfExactType<MBTheme>();
    assert(
      scope != null,
      'MBTheme not found in widget tree. Wrap your app in MBTheme.',
    );
    return scope!.tokens;
  }

  /// Read tokens without subscribing to rebuilds.
  static MBTokens read(BuildContext context) {
    final MBTheme? scope = context.getInheritedWidgetOfExactType<MBTheme>();
    assert(
      scope != null,
      'MBTheme not found in widget tree. Wrap your app in MBTheme.',
    );
    return scope!.tokens;
  }

  @override
  bool updateShouldNotify(MBTheme oldWidget) =>
      tokens.colors != oldWidget.tokens.colors ||
      tokens.brightness != oldWidget.tokens.brightness;
}

extension MBThemeContext on BuildContext {
  /// Shorthand for [MBTheme.of].
  MBTokens get mb => MBTheme.of(this);
}

/// Build a [CupertinoThemeData] aligned with Magic Box tokens for the given brightness.
CupertinoThemeData buildCupertinoTheme(Brightness brightness) {
  final MBColors c = brightness == Brightness.dark
      ? MBColors.dark()
      : MBColors.light();

  TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);

  final CupertinoTextThemeData textTheme = CupertinoTextThemeData(
    primaryColor: c.textPri,
    textStyle: withColor(MBTextStyles.body, c.textPri),
    actionTextStyle: withColor(MBTextStyles.body, c.accent),
    tabLabelTextStyle: withColor(MBTextStyles.caption2, c.textTer),
    navTitleTextStyle: withColor(MBTextStyles.headline, c.textPri),
    navLargeTitleTextStyle: withColor(MBTextStyles.largeTitle, c.textPri),
    navActionTextStyle: withColor(MBTextStyles.body, c.accent),
    pickerTextStyle: withColor(MBTextStyles.title3, c.textPri),
    dateTimePickerTextStyle: withColor(MBTextStyles.title3, c.textPri),
  );

  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: c.accent,
    primaryContrastingColor: c.textInverse,
    scaffoldBackgroundColor: c.bg,
    barBackgroundColor: c.surface,
    textTheme: textTheme,
    applyThemeToAll: true,
  );
}
