import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/window_content.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor timestamp = UtilityCatalog.byId('timestamp');
  final UtilityDescriptor generator = UtilityCatalog.byId('generator');
  final UtilityDescriptor base64Tool = UtilityCatalog.byId('base64');
  const String encodedCredential =
      'eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsLWZpeHR1cmUifQ==';

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
      expect(restored.cards[0].toolDescriptor!.id, 'json');
      expect(restored.cards[0].x, 120);
      expect(restored.cards[0].y, 220);
      expect(restored.cards[0].width, 600);
      expect(restored.cards[0].seed, '{"a":1}');
      expect(restored.focusedId, restored.cards[0].id);
    });

    test('omits credential and sensitive-tool seeds from serialized state', () {
      final CanvasController c = CanvasController();
      c.openTool(json, seed: '{"password":"raw-credential-fixture"}');
      c.openTool(generator, seed: 'opaque-generated-fixture');

      final String serialized = jsonEncode(c.toJson());

      expect(serialized, isNot(contains('raw-credential-fixture')));
      expect(serialized, isNot(contains('opaque-generated-fixture')));
      for (final dynamic card in c.toJson()['cards'] as List<dynamic>) {
        expect(card as Map<String, dynamic>, isNot(contains('seed')));
      }
    });

    test('omits reversibly encoded credential seeds', () {
      final CanvasController c = CanvasController();
      c.openTool(base64Tool, seed: encodedCredential);
      c.openTool(
        UtilityCatalog.byId('bytes'),
        seed:
            '123 34 112 97 115 115 119 111 114 100 34 58 34 114 97 119 45 99 114 101 100 101 110 116 105 97 108 45 102 105 120 116 117 114 101 34 125',
      );
      c.openTool(
        UtilityCatalog.byId('url'),
        seed: '%7B%22password%22%3A%22raw-credential-fixture%22%7D',
      );

      final Map<String, dynamic> serialized = c.toJson();
      expect(jsonEncode(serialized), isNot(contains(encodedCredential)));
      for (final dynamic card in serialized['cards'] as List<dynamic>) {
        expect(card as Map<String, dynamic>, isNot(contains('seed')));
      }
    });

    test('omits canonical values linked to a sensitive tool', () {
      final CanvasController c = CanvasController();
      final int source = c.openTool(generator);
      final int target = c.openTool(json);
      c.linkCards(
        source,
        target,
        type: ContentType.text,
        seedCanonical: 'opaque-generated-fixture',
      );

      final String serialized = jsonEncode(c.toJson());
      final Map<String, dynamic> group =
          (c.toJson()['groups'] as List<dynamic>).single
              as Map<String, dynamic>;

      expect(serialized, isNot(contains('opaque-generated-fixture')));
      expect(group['canonical'], isEmpty);
    });

    test('sanitizes legacy sensitive seeds and group state on apply', () {
      final CanvasController c = CanvasController()
        ..applyJson(<String, dynamic>{
          'cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'tool': 'generator',
              'x': 0,
              'y': 0,
              'w': 380,
              'seed': 'opaque-generated-fixture',
            },
            <String, dynamic>{
              'id': 2,
              'tool': 'json',
              'x': 0,
              'y': 0,
              'w': 380,
            },
          ],
          'groups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'type': 'text',
              'canonical': 'opaque-generated-fixture',
              'members': <int>[1, 2],
            },
          ],
        });

      expect(c.cards.first.seed, isNull);
      expect(c.groups.single.canonical.value, isEmpty);
      expect(
        jsonEncode(c.toJson()),
        isNot(contains('opaque-generated-fixture')),
      );
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
      expect(c.cards.single.toolDescriptor!.id, 'json');
    });

    test('old snapshot without z/minimized/maximized loads with defaults', () {
      final CanvasController c = CanvasController();
      final Map<String, dynamic> oldJson = <String, dynamic>{
        'nextId': 3,
        'focused': 1,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'tool': 'json',
            'x': 50,
            'y': 60,
            'w': 400.0,
          },
          <String, dynamic>{
            'id': 2,
            'tool': 'timestamp',
            'x': 100,
            'y': 100,
            'w': 380.0,
          },
        ],
      };
      c.applyJson(oldJson);

      expect(c.length, 2);
      expect(c.cards[0].z, 1); // defaults to id
      expect(c.cards[1].z, 2);
      expect(c.cards[0].minimized, isFalse);
      expect(c.cards[0].maximized, isFalse);
      expect(c.cards[0].height, isNull);
      expect(c.cards[0].restoreBounds, isNull);
    });

    test('round-trips z, minimized, maximized, height, restoreBounds', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(json);
      c.openTool(timestamp);
      c.maximize(a, x: 0, y: 0, width: 1200, height: 800);
      c.minimize(c.cards[1].id);

      final CanvasController restored = CanvasController()
        ..applyJson(c.toJson());

      expect(restored.cards[0].maximized, isTrue);
      expect(restored.cards[0].height, 800);
      expect(restored.cards[0].restoreBounds, isNotNull);
      expect(restored.cards[1].minimized, isTrue);
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
      expect(reborn.cards.single.toolDescriptor!.id, 'json');
      expect(reborn.cards.single.seed, 'hello');
    });

    test('restore is a no-op when nothing was saved', () {
      final CanvasController c = CanvasController()..restore();
      expect(c.isEmpty, isTrue);
    });

    test(
      'restore drops and rewrites a legacy encoded credential seed',
      () async {
        final Map<String, dynamic> legacy = <String, dynamic>{
          'cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'tool': 'base64',
              'x': 0,
              'y': 0,
              'w': 380,
              'seed': encodedCredential,
            },
          ],
        };
        SharedPreferences.setMockInitialValues(<String, Object>{
          CanvasController.currentKey: jsonEncode(legacy),
        });
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        final CanvasController c = CanvasController(prefs: prefs)..restore();
        await Future<void>.delayed(Duration.zero);

        expect(c.cards.single.seed, isNull);
        expect(
          prefs.getString(CanvasController.currentKey),
          isNot(contains(encodedCredential)),
        );
      },
    );
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
      expect(c.cards.first.toolDescriptor!.id, 'json');

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

    test('sanitizes an encoded credential seed in a legacy layout', () async {
      final Map<String, dynamic> legacy = <String, dynamic>{
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'tool': 'base64',
            'x': 0,
            'y': 0,
            'w': 380,
            'seed': encodedCredential,
          },
        ],
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        CanvasController.layoutsKey: jsonEncode(<String, dynamic>{
          'Legacy': legacy,
        }),
      });

      await CanvasController.clearPersistedSensitiveSession();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String layouts = prefs.getString(CanvasController.layoutsKey)!;
      expect(layouts, isNot(contains(encodedCredential)));
      expect((jsonDecode(layouts) as Map<String, dynamic>).keys, <String>[
        'Legacy',
      ]);
    });
  });

  group('system window persistence', () {
    test('round-trips a system window', () {
      final CanvasController c = CanvasController();
      c.openSystem(SystemApp.history);
      c.openTool(json);

      final CanvasController restored = CanvasController()
        ..applyJson(c.toJson());

      expect(restored.length, 2);
      expect(restored.cards[0].content, isA<SystemWindow>());
      expect(
        (restored.cards[0].content as SystemWindow).app,
        SystemApp.history,
      );
      expect(restored.cards[1].toolDescriptor!.id, 'json');
    });

    test('old tool-only snapshot still loads (backward compat)', () {
      final CanvasController c = CanvasController();
      final Map<String, dynamic> oldJson = <String, dynamic>{
        'nextId': 2,
        'focused': 1,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'tool': 'json',
            'x': 50,
            'y': 60,
            'w': 400.0,
          },
        ],
      };
      c.applyJson(oldJson);
      expect(c.length, 1);
      expect(c.cards.single.toolDescriptor!.id, 'json');
    });

    test('unknown system app name is dropped', () {
      final CanvasController c = CanvasController();
      final Map<String, dynamic> json0 = <String, dynamic>{
        'nextId': 3,
        'focused': null,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'system': 'unknown_app',
            'x': 0,
            'y': 0,
            'w': 440.0,
          },
          <String, dynamic>{
            'id': 2,
            'tool': 'json',
            'x': 0,
            'y': 0,
            'w': 380.0,
          },
        ],
      };
      c.applyJson(json0);
      expect(c.length, 1);
      expect(c.cards.single.toolDescriptor!.id, 'json');
    });
  });
}
