import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ViewModeController', () {
    test('default mode is desktop', () {
      expect(ViewModeController().mode, MqViewMode.desktop);
    });

    test('setMode notifies listeners and persists', () async {
      int notifyCount = 0;
      final ViewModeController c = ViewModeController();
      c.addListener(() => notifyCount++);

      await c.setMode(MqViewMode.mobile);
      expect(notifyCount, 1);
      expect(c.mode, MqViewMode.mobile);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mb.view.mode'), 'mobile');
    });

    test('setMode is a no-op when mode is unchanged', () async {
      int notifyCount = 0;
      final ViewModeController c = ViewModeController();
      c.addListener(() => notifyCount++);
      await c.setMode(MqViewMode.desktop);
      expect(notifyCount, 0);
    });

    test('toggle flips between desktop and mobile', () async {
      final ViewModeController c = ViewModeController();
      await c.toggle();
      expect(c.mode, MqViewMode.mobile);
      await c.toggle();
      expect(c.mode, MqViewMode.desktop);
    });

    test('load() hydrates persisted mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.view.mode': 'mobile',
      });
      final ViewModeController c = await ViewModeController.load();
      expect(c.mode, MqViewMode.mobile);
    });

    test('load() falls back to desktop on missing/invalid values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mb.view.mode': 'bogus',
      });
      final ViewModeController c = await ViewModeController.load();
      expect(c.mode, MqViewMode.desktop);
    });
  });
}
