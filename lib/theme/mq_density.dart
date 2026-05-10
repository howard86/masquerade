import 'package:flutter/widgets.dart';

import 'mq_metrics.dart';
import 'mq_theme.dart';

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

/// Density resolves through [MqTheme] — there is no separate scope to wire.
extension MqDensityContext on BuildContext {
  MqDensity get density => MqTheme.of(this).density;
}
