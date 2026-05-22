import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor timestamp = UtilityCatalog.byId('timestamp');

  group('toJson / applyJson (pure round-trip)', () {
    test('preserves tool, geometry, seed, and focus', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(json, seed: '{"a":1}');
      c.openTool(timestamp);
      c.moveTo(a, 120, 220);
      c.resize(a, 600);
      c.focus(a);

      final CanvasController restored = CanvasController()
        ..applyJson(c.toJson());

      expect(restored.length, 2);
      expect(restored.cards[0].descriptor.id, 'json');
      expect(restored.cards[0].x, 120);
      expect(restored.cards[0].y, 220);
      expect(restored.cards[0].width, 600);
      expect(restored.cards[0].seed, '{"a":1}');
      expect(restored.focusedId, restored.cards[0].id);
    });

    test('drops cards whose tool id no longer exists', () {
      final CanvasController c = CanvasController();
      final Map<String, dynamic> json0 = <String, dynamic>{
        'nextId': 5,
        'focused': null,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'tool': 'json',
            'x': 0,
            'y': 0,
            'w': 380.0,
          },
          <String, dynamic>{
            'id': 2,
            'tool': 'ghost',
            'x': 0,
            'y': 0,
            'w': 380.0,
          },
        ],
      };
      c.applyJson(json0);
      expect(c.length, 1);
      expect(c.cards.single.descriptor.id, 'json');
    });
  });

  group('auto-restore via prefs', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('a mutation persists and a fresh controller restores it', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController c = CanvasController(prefs: prefs);
      c.openTool(json, seed: 'hello');
      await Future<void>.delayed(Duration.zero);

      final CanvasController reborn = CanvasController(prefs: prefs)..restore();

      expect(reborn.length, 1);
      expect(reborn.cards.single.descriptor.id, 'json');
      expect(reborn.cards.single.seed, 'hello');
    });

    test('restore is a no-op when nothing was saved', () {
      final CanvasController c = CanvasController()..restore();
      expect(c.isEmpty, isTrue);
    });
  });

  group('named layouts', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('save, list, restore, delete', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController c = CanvasController(prefs: prefs);
      c.openTool(json, seed: '{"k":1}');
      c.openTool(timestamp);

      c.saveLayout('JWT debug');
      await Future<void>.delayed(Duration.zero);
      expect(c.layoutNames, <String>['JWT debug']);

      c.closeAll();
      expect(c.isEmpty, isTrue);

      c.restoreLayout('JWT debug');
      expect(c.length, 2);
      expect(c.cards.first.descriptor.id, 'json');

      c.deleteLayout('JWT debug');
      await Future<void>.delayed(Duration.zero);
      expect(c.layoutNames, isEmpty);
    });

    test('blank name and missing-layout restore are no-ops', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController c = CanvasController(prefs: prefs);
      c.openTool(json);

      c.saveLayout('   ');
      await Future<void>.delayed(Duration.zero);
      expect(c.layoutNames, isEmpty);

      c.restoreLayout('nope'); // no throw, no change
      expect(c.length, 1);
    });
  });
}
