import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/density_controller.dart';
import 'package:masquerade/theme/mq_density.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DensityController', () {
    test('default mode is comfortable', () {
      final DensityController c = DensityController();
      expect(c.mode, MqDensityMode.comfortable);
      expect(c.density.isCompact, isFalse);
      expect(c.density.cardPadding, MqDensity.kComfortable.cardPadding);
    });

    test('setMode notifies listeners and persists', () async {
      int notifyCount = 0;
      final DensityController c = DensityController();
      c.addListener(() => notifyCount++);

      await c.setMode(MqDensityMode.compact);
      expect(notifyCount, 1);
      expect(c.mode, MqDensityMode.compact);
      expect(c.density.cardPadding, MqDensity.kCompact.cardPadding);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mb.density.mode'), 'compact');
    });

    test('setMode is a no-op when mode is unchanged', () async {
      int notifyCount = 0;
      final DensityController c = DensityController();
      c.addListener(() => notifyCount++);
      await c.setMode(MqDensityMode.comfortable);
      expect(notifyCount, 0);
    });

    test('load() hydrates persisted mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.density.mode': 'compact',
      });
      final DensityController c = await DensityController.load();
      expect(c.mode, MqDensityMode.compact);
    });

    test(
      'load() falls back to comfortable on missing/invalid values',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'mb.density.mode': 'bogus',
        });
        final DensityController c = await DensityController.load();
        expect(c.mode, MqDensityMode.comfortable);
      },
    );
  });
}
