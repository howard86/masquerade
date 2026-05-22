import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/utility_catalog.dart';

void main() {
  final UtilityDescriptor timestamp = UtilityCatalog.byId('timestamp');
  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor diff = UtilityCatalog.byId('diff');

  group('openTool', () {
    test('adds a card, returns its id, and focuses it', () {
      final CanvasController c = CanvasController();
      int notified = 0;
      c.addListener(() => notified++);

      final int id = c.openTool(timestamp);

      expect(c.length, 1);
      expect(c.cards.single.id, id);
      expect(c.focusedId, id);
      expect(notified, 1);
    });

    test('opens at the tool\'s default card width', () {
      final CanvasController c = CanvasController();
      c.openTool(timestamp); // standard
      c.openTool(json); // xwide
      c.openTool(diff); // xwide

      expect(c.cards[0].width, CardWidthClass.standard.px);
      expect(c.cards[1].width, CardWidthClass.xwide.px);
      expect(c.cards[2].width, CardWidthClass.xwide.px);
    });

    test('cascades each new card down-and-right', () {
      final CanvasController c = CanvasController(cascadeStep: 32);
      c.openTool(timestamp);
      c.openTool(timestamp);

      expect(c.cards[1].x, greaterThan(c.cards[0].x));
      expect(c.cards[1].y, greaterThan(c.cards[0].y));
    });

    test('treats an empty seed as no seed', () {
      final CanvasController c = CanvasController();
      c.openTool(timestamp, seed: '');
      c.openTool(timestamp, seed: '1747929600');

      expect(c.cards[0].seed, isNull);
      expect(c.cards[1].seed, '1747929600');
    });
  });

  group('close', () {
    test('removes the card and falls focus back to the last remaining', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(timestamp);
      final int b = c.openTool(json);
      c.focus(a);

      c.close(a);

      expect(c.length, 1);
      expect(c.cards.single.id, b);
      expect(c.focusedId, b);
    });

    test('unknown id is a no-op (no notification)', () {
      final CanvasController c = CanvasController();
      c.openTool(timestamp);
      int notified = 0;
      c.addListener(() => notified++);

      c.close(9999);

      expect(c.length, 1);
      expect(notified, 0);
    });

    test('closeAll empties the canvas and clears focus', () {
      final CanvasController c = CanvasController();
      c.openTool(timestamp);
      c.openTool(json);

      c.closeAll();

      expect(c.isEmpty, isTrue);
      expect(c.focusedId, isNull);
    });
  });

  group('focus slots (⌥1–9)', () {
    test('cardInSlot is 1-based in open order', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(timestamp);
      final int b = c.openTool(json);

      expect(c.cardInSlot(1)!.id, a);
      expect(c.cardInSlot(2)!.id, b);
      expect(c.cardInSlot(3), isNull);
    });

    test('focusSlot focuses the card in that slot', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(timestamp);
      c.openTool(json);

      c.focusSlot(1);

      expect(c.focusedId, a);
    });

    test('focusSlot on an empty slot is a no-op', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(timestamp);

      c.focusSlot(5);

      expect(c.focusedId, a);
    });
  });

  group('moveTo', () {
    test('sets absolute position', () {
      final CanvasController c = CanvasController();
      final int id = c.openTool(timestamp);

      c.moveTo(id, 200, 150);

      expect(c.cards.single.x, 200);
      expect(c.cards.single.y, 150);
    });

    test('clamps negative coordinates to the origin', () {
      final CanvasController c = CanvasController();
      final int id = c.openTool(timestamp);

      c.moveTo(id, -50, -20);

      expect(c.cards.single.x, 0);
      expect(c.cards.single.y, 0);
    });
  });

  group('resize', () {
    test('clamps to the width bounds', () {
      final CanvasController c = CanvasController();
      final int id = c.openTool(timestamp);

      c.resize(id, 99999);
      expect(c.cards.single.width, CanvasController.maxCardWidth);

      c.resize(id, 1);
      expect(c.cards.single.width, CanvasController.minCardWidth);
    });

    test('a no-change resize does not notify', () {
      final CanvasController c = CanvasController();
      final int id = c.openTool(json);
      int notified = 0;
      c.addListener(() => notified++);

      c.resize(id, c.cards.single.width);

      expect(notified, 0);
    });
  });

  group('duplicate', () {
    test('copies tool, width, and seed, offset from the source', () {
      final CanvasController c = CanvasController(cascadeStep: 32);
      final int src = c.openTool(json, seed: '{"a":1}');

      final int? dup = c.duplicate(src);

      expect(dup, isNotNull);
      expect(c.length, 2);
      final CanvasCard a = c.cards[0];
      final CanvasCard b = c.cards[1];
      expect(b.descriptor.id, a.descriptor.id);
      expect(b.width, a.width);
      expect(b.seed, a.seed);
      expect(b.x, a.x + 32);
      expect(b.y, a.y + 32);
      expect(c.focusedId, dup);
    });

    test('returns null for an unknown id', () {
      final CanvasController c = CanvasController();
      expect(c.duplicate(123), isNull);
    });
  });
}
