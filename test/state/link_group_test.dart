import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/utility_catalog.dart';

void main() {
  final UtilityDescriptor base64 = UtilityCatalog.byId('base64');
  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor timestamp = UtilityCatalog.byId('timestamp');

  group('linkCards', () {
    test('groups two cards on one canonical value', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);

      c.linkCards(a, b, type: ContentType.text, seedCanonical: 'hi');

      final LinkGroup? g = c.groupForCard(a);
      expect(g, isNotNull);
      expect(g!.members, <int>{a, b});
      expect(g.type, ContentType.text);
      expect(g.canonical.value, 'hi');
      expect(c.groupForCard(b), same(g));
      expect(c.hasLinks, isTrue);
    });

    test('a third card joins the existing group, not a new one', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      final int third = c.openTool(timestamp);

      c.linkCards(a, b, type: ContentType.text);
      c.linkCards(b, third, type: ContentType.text);

      expect(c.groups.length, 1);
      expect(c.groupForCard(third)!.members, <int>{a, b, third});
    });
  });

  group('channel emit (canonical hub)', () {
    test('emit updates canonical and notifies other members; idempotent', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text, seedCanonical: 'start');

      final LinkChannel chA = c.channelForCard(a)!;
      final LinkGroup g = c.groupForCard(a)!;
      int fired = 0;
      g.canonical.addListener(() => fired++);

      chA.emit('changed');
      expect(g.canonical.value, 'changed');
      expect(fired, 1);

      chA.emit('changed'); // same value → no-op, no cycle
      expect(fired, 1);
    });

    test('channelForCard is null for an unlinked card', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      expect(c.channelForCard(a), isNull);
    });
  });

  group('detach', () {
    test('unlinkCard dissolves a two-member group', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text);

      c.unlinkCard(a);

      expect(c.hasLinks, isFalse);
      expect(c.groupForCard(b), isNull);
    });

    test('closing a card detaches it from its group', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text);

      c.close(a);

      expect(c.hasLinks, isFalse);
    });
  });

  group('persistence', () {
    test('groups round-trip through toJson/applyJson', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text, seedCanonical: 'payload');

      final CanvasController restored = CanvasController()
        ..applyJson(c.toJson());

      expect(restored.groups.length, 1);
      final LinkGroup g = restored.groups.single;
      expect(g.members, <int>{a, b});
      expect(g.type, ContentType.text);
      expect(g.canonical.value, 'payload');
    });

    test('a group whose members no longer exist is dropped', () {
      final CanvasController c = CanvasController();
      c.applyJson(<String, dynamic>{
        'nextId': 3,
        'nextGroupId': 2,
        'focused': null,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'tool': 'json',
            'x': 0,
            'y': 0,
            'w': 380.0,
          },
        ],
        'groups': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'type': 'text',
            'canonical': 'x',
            'members': <int>[1, 2], // card 2 doesn't exist → only one survives
          },
        ],
      });

      expect(c.length, 1);
      expect(c.hasLinks, isFalse);
    });
  });
}
