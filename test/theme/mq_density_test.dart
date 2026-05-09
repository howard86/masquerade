import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_density.dart';
import 'package:masquerade/theme/mq_metrics.dart';

void main() {
  group('MqDensity', () {
    test('comfortable token values match scale', () {
      const MqDensity d = MqDensity.kComfortable;
      expect(d.mode, MqDensityMode.comfortable);
      expect(d.screenPadding, MqSpacing.lg);
      expect(d.headerPadding, MqSpacing.xl);
      expect(d.cardPadding, MqSpacing.lg);
      expect(d.cardGap, MqSpacing.md);
      expect(d.minTarget, 44);
      expect(d.isCompact, isFalse);
    });

    test('compact token values match scale', () {
      const MqDensity d = MqDensity.kCompact;
      expect(d.mode, MqDensityMode.compact);
      expect(d.screenPadding, MqSpacing.md);
      expect(d.headerPadding, MqSpacing.lg);
      expect(d.cardPadding, MqSpacing.md);
      expect(d.cardGap, MqSpacing.sm);
      expect(d.minTarget, 36);
      expect(d.isCompact, isTrue);
    });

    test('comfortable and compact are not equal', () {
      expect(MqDensity.kComfortable == MqDensity.kCompact, isFalse);
    });

    test('factory constructors return canonical const instances', () {
      expect(
        identical(MqDensity.comfortable(), MqDensity.kComfortable),
        isTrue,
      );
      expect(identical(MqDensity.compact(), MqDensity.kCompact), isTrue);
    });
  });
}
