import 'package:flutter/cupertino.dart';

import 'mq_colors.dart';
import 'mq_density.dart';
import 'mq_typography.dart';

/// Bundle of Masquerade tokens for a single mode. Resolved via [MqTheme.of].
@immutable
class MqTokens {
  const MqTokens({
    required this.colors,
    required this.brightness,
    this.density = MqDensity.kComfortable,
  });
  final MqColors colors;
  final Brightness brightness;
  final MqDensity density;

  bool get isDark => brightness == Brightness.dark;
}

/// Inherited bridge that exposes [MqTokens] beneath a [CupertinoApp].
class MqTheme extends InheritedWidget {
  const MqTheme({super.key, required this.tokens, required super.child});

  final MqTokens tokens;

  static MqTokens of(BuildContext context) {
    final MqTheme? scope = context
        .dependOnInheritedWidgetOfExactType<MqTheme>();
    assert(
      scope != null,
      'MqTheme not found in widget tree. Wrap your app in MqTheme.',
    );
    return scope!.tokens;
  }

  /// Read tokens without subscribing to rebuilds.
  static MqTokens read(BuildContext context) {
    final MqTheme? scope = context.getInheritedWidgetOfExactType<MqTheme>();
    assert(
      scope != null,
      'MqTheme not found in widget tree. Wrap your app in MqTheme.',
    );
    return scope!.tokens;
  }

  @override
  bool updateShouldNotify(MqTheme oldWidget) =>
      tokens.colors != oldWidget.tokens.colors ||
      tokens.brightness != oldWidget.tokens.brightness ||
      tokens.density != oldWidget.tokens.density;
}

extension MqThemeContext on BuildContext {
  /// Shorthand for [MqTheme.of].
  MqTokens get mq => MqTheme.of(this);
}

/// Build a [CupertinoThemeData] aligned with Masquerade tokens for the given brightness.
CupertinoThemeData buildCupertinoTheme(Brightness brightness) {
  final MqColors c = brightness == Brightness.dark
      ? MqColors.dark()
      : MqColors.light();

  TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);

  final CupertinoTextThemeData textTheme = CupertinoTextThemeData(
    primaryColor: c.textPri,
    textStyle: withColor(MqTextStyles.body, c.textPri),
    actionTextStyle: withColor(MqTextStyles.body, c.accent),
    tabLabelTextStyle: withColor(MqTextStyles.caption2, c.textTer),
    navTitleTextStyle: withColor(MqTextStyles.headline, c.textPri),
    navLargeTitleTextStyle: withColor(MqTextStyles.largeTitle, c.textPri),
    navActionTextStyle: withColor(MqTextStyles.body, c.accent),
    pickerTextStyle: withColor(MqTextStyles.title3, c.textPri),
    dateTimePickerTextStyle: withColor(MqTextStyles.title3, c.textPri),
  );

  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: c.accent,
    primaryContrastingColor: c.onTint,
    scaffoldBackgroundColor: c.bg,
    barBackgroundColor: c.surface,
    textTheme: textTheme,
    applyThemeToAll: true,
  );
}
