import 'package:flutter/widgets.dart';

import 'mq_metrics.dart';

/// Density mode controls comfortable vs compact spacing across the app.
enum MqDensityMode { comfortable, compact }

/// Resolved spacing tokens for a density mode. Components query these
/// via `context.density` rather than reading raw [MqSpacing] constants,
/// so the comfortable/compact mapping lives in one place.
@immutable
class MqDensity {
  const MqDensity({
    required this.mode,
    required this.screenPadding,
    required this.headerPadding,
    required this.cardPadding,
    required this.cardGap,
    required this.minTarget,
  });

  static const MqDensity kComfortable = MqDensity(
    mode: MqDensityMode.comfortable,
    screenPadding: MqSpacing.lg,
    headerPadding: MqSpacing.xl,
    cardPadding: MqSpacing.lg,
    cardGap: MqSpacing.md,
    minTarget: 44,
  );

  static const MqDensity kCompact = MqDensity(
    mode: MqDensityMode.compact,
    screenPadding: MqSpacing.md,
    headerPadding: MqSpacing.lg,
    cardPadding: MqSpacing.md,
    cardGap: MqSpacing.sm,
    minTarget: 36,
  );

  factory MqDensity.comfortable() => kComfortable;
  factory MqDensity.compact() => kCompact;

  final MqDensityMode mode;
  final double screenPadding;
  final double headerPadding;
  final double cardPadding;
  final double cardGap;
  final double minTarget;

  EdgeInsets get screenInsets =>
      EdgeInsets.symmetric(horizontal: screenPadding);
  EdgeInsets get cardInsets => EdgeInsets.all(cardPadding);

  bool get isCompact => mode == MqDensityMode.compact;

  @override
  bool operator ==(Object other) =>
      other is MqDensity &&
      other.mode == mode &&
      other.screenPadding == screenPadding &&
      other.headerPadding == headerPadding &&
      other.cardPadding == cardPadding &&
      other.cardGap == cardGap &&
      other.minTarget == minTarget;

  @override
  int get hashCode => Object.hash(
    mode,
    screenPadding,
    headerPadding,
    cardPadding,
    cardGap,
    minTarget,
  );
}

/// Provides [MqDensity] to descendants. Resolved by `context.density`.
class MqDensityScope extends InheritedWidget {
  const MqDensityScope({
    super.key,
    required this.density,
    required super.child,
  });

  final MqDensity density;

  static MqDensity of(BuildContext context) {
    final MqDensityScope? scope = context
        .dependOnInheritedWidgetOfExactType<MqDensityScope>();
    return scope?.density ?? MqDensity.comfortable();
  }

  @override
  bool updateShouldNotify(MqDensityScope oldWidget) =>
      density != oldWidget.density;
}

extension MqDensityContext on BuildContext {
  MqDensity get density => MqDensityScope.of(this);
}
