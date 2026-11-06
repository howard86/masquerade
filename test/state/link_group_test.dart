import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/window_content.dart';
import 'package:masquerade/utility_catalog.dart';

void main() {
  final UtilityDescriptor base64 = UtilityCatalog.byId('base64');
  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor diff = UtilityCatalog.byId('diff');
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
      final int third = c.openTool(UtilityCatalog.byId('list'));

      c.linkCards(a, b, type: ContentType.text);
      c.linkCards(b, third, type: ContentType.text);

      expect(c.groups.length, 1);
      expect(c.groupForCard(third)!.members, <int>{a, b, third});
      expect(c.channelForCard(a)!.seedOnAttach, isTrue);
    });

    test('a new group marks only its selected source as the seeder', () {
      final CanvasController c = CanvasController();
      final int source = c.openTool(base64);
      final int target = c.openTool(json);
      c.linkCards(source, target, type: ContentType.text);

      expect(c.channelForCard(source)!.seedOnAttach, isTrue);
      expect(c.channelForCard(target)!.seedOnAttach, isFalse);
    });

    test('seed authority is consumed through cached channel wrappers', () {
      final CanvasController c = CanvasController();
      final int source = c.openTool(base64);
      final int target = c.openTool(json);
      c.linkCards(source, target, type: ContentType.text);
      final LinkChannel cachedSourceChannel = c.channelForCard(source)!;

      expect(cachedSourceChannel.seedOnAttach, isTrue);
      cachedSourceChannel.consumeSeedOwnership();

      expect(cachedSourceChannel.seedOnAttach, isFalse);
      expect(c.channelForCard(source)!.seedOnAttach, isFalse);
      expect(c.channelForCard(target)!.seedOnAttach, isFalse);
    });

    test('repeated links are idempotent', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text);
      int notifications = 0;
      c.addListener(() => notifications++);

      final int? groupId = c.linkCards(a, b, type: ContentType.text);
      final int? wrongType = c.linkCards(a, b, type: ContentType.lines);

      expect(groupId, c.groups.single.id);
      expect(wrongType, isNull);
      expect(c.groups.single.members, <int>{a, b});
      expect(notifications, 0);
    });

    test(
      'merging two groups keeps the source canonical and one membership',
      () {
        final CanvasController c = CanvasController();
        final int source = c.openTool(base64);
        final int sourcePeer = c.openTool(json);
        final int target = c.openTool(diff);
        final int targetPeer = c.openTool(UtilityCatalog.byId('list'));
        c.linkCards(
          source,
          sourcePeer,
          type: ContentType.text,
          seedCanonical: 'source value',
        );
        c.linkCards(
          target,
          targetPeer,
          type: ContentType.text,
          seedCanonical: 'target value',
        );

        final int? result = c.linkCards(source, target, type: ContentType.text);

        expect(result, c.groupForCard(source)!.id);
        expect(c.groups, hasLength(1));
        expect(c.groups.single.members, <int>{
          source,
          sourcePeer,
          target,
          targetPeer,
        });
        expect(c.groups.single.canonical.value, 'source value');
        for (final int id in <int>[source, sourcePeer, target, targetPeer]) {
          expect(
            c.groups.where((LinkGroup g) => g.members.contains(id)),
            hasLength(1),
          );
        }
      },
    );

    test('merging before attach preserves the selected source window', () {
      final CanvasController c = CanvasController();
      final int source = c.openTool(base64);
      final int sourcePeer = c.openTool(json);
      final int target = c.openTool(diff);
      final int targetPeer = c.openTool(UtilityCatalog.byId('list'));
      c.linkCards(source, sourcePeer, type: ContentType.text);
      c.linkCards(
        target,
        targetPeer,
        type: ContentType.text,
        seedCanonical: 'target value',
      );

      c.linkCards(source, target, type: ContentType.text);

      expect(c.channelForCard(source)!.seedOnAttach, isTrue);
      expect(c.channelForCard(sourcePeer)!.seedOnAttach, isFalse);
    });

    test('stale, self, system, and unsupported links are rejected', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(timestamp);
      final int system = c.openSystem(SystemApp.history);

      expect(
        c.linkIssueFor(999, b, type: ContentType.text),
        LinkIssue.sourceMissing,
      );
      expect(
        c.linkIssueFor(a, 999, type: ContentType.text),
        LinkIssue.targetMissing,
      );
      expect(
        c.linkIssueFor(a, a, type: ContentType.text),
        LinkIssue.sameWindow,
      );
      expect(
        c.linkIssueFor(a, system, type: ContentType.text),
        LinkIssue.notToolWindow,
      );
      expect(
        c.linkIssueFor(a, b, type: ContentType.text),
        LinkIssue.targetUnsupported,
      );

      expect(c.linkCards(a, b, type: ContentType.text), isNull);
      expect(c.groups, isEmpty);
    });

    test('a conflicting group type must be unlinked before changing type', () {
      final CanvasController c = CanvasController();
      final int epoch = c.openTool(timestamp);
      final int math = c.openTool(UtilityCatalog.byId('math'));
      final int number = c.openTool(UtilityCatalog.byId('number_base'));
      c.linkCards(epoch, math, type: ContentType.epoch);

      expect(
        c.linkIssueFor(math, number, type: ContentType.number),
        LinkIssue.groupTypeConflict,
      );
      expect(c.linkCards(math, number, type: ContentType.number), isNull);
      expect(c.linkCards(math, epoch, type: ContentType.number), isNull);
      expect(c.groupForCard(math)!.members, <int>{epoch, math});
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

    test('invalid and duplicate saved memberships are sanitized', () {
      final CanvasController c = CanvasController()
        ..applyJson(<String, dynamic>{
          'nextId': 5,
          'nextGroupId': 4,
          'focused': null,
          'cards': <Map<String, dynamic>>[
            for (final (int, String) entry in <(int, String)>[
              (1, 'json'),
              (2, 'timestamp'),
              (3, 'list'),
              (4, 'diff'),
            ])
              <String, dynamic>{
                'id': entry.$1,
                'tool': entry.$2,
                'x': 0,
                'y': 0,
                'w': 380.0,
              },
          ],
          'groups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'type': 'text',
              'canonical': 'kept',
              'members': <int>[1, 2], // timestamp cannot join text.
            },
            <String, dynamic>{
              'id': 2,
              'type': 'text',
              'canonical': 'valid',
              'members': <int>[1, 3],
            },
            <String, dynamic>{
              'id': 3,
              'type': 'text',
              'canonical': 'duplicate',
              'members': <int>[3, 4], // card 3 is already in group 2.
            },
          ],
        });

      expect(c.groups, hasLength(1));
      expect(c.groups.single.members, <int>{1, 3});
      expect(c.groupForCard(2), isNull);
      expect(c.groupForCard(4), isNull);
    });
  });

  group('link roles', () {
    test('extension flags and labels', () {
      expect(LinkRole.both.sends && LinkRole.both.receives, isTrue);
      expect(LinkRole.receive.sends, isFalse);
      expect(LinkRole.receive.receives, isTrue);
      expect(LinkRole.both.label, 'Two-way');
      expect(LinkRole.receive.label, 'Follow only');
    });

    test('source always owns the seed; targetFollows makes b a follower', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text, targetFollows: true);
      final LinkGroup g = c.groupForCard(a)!;
      expect(g.seedOwnerCardId, a);
      expect(c.isFollower(b), isTrue);
      expect(c.isFollower(a), isFalse);
      expect(c.channelForCard(b)!.role, LinkRole.receive);

      final CanvasController d = CanvasController();
      final int x = d.openTool(base64);
      final int y = d.openTool(json);
      d.linkCards(x, y, type: ContentType.text);
      expect(d.isFollower(y), isFalse);
      expect(d.isFollower(999), isFalse);
    });

    test('a follower never changes canonical via the group', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text, seedCanonical: 'v');
      c.setFollower(b, true);
      expect(c.groupForCard(a)!.canonical.value, 'v');
      c.channelForCard(a)!.emit('w');
      expect(c.groupForCard(a)!.canonical.value, 'w');
      expect(c.channelForCard(b)!.role.sends, isFalse);
    });

    test('canFollow and setFollower refuse the last sender', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      final int lone = c.openTool(diff);
      expect(c.canFollow(lone), isFalse);
      int notified = 0;
      c.addListener(() => notified++);
      expect(c.setFollower(lone, true), isFalse);
      expect(notified, 0);

      c.linkCards(a, b, type: ContentType.text);
      notified = 0;
      expect(c.canFollow(a), isTrue);
      expect(c.setFollower(a, true), isTrue);
      expect(notified, 1);
      expect(c.canFollow(b), isFalse);
      expect(c.setFollower(b, true), isFalse);
      expect(c.isFollower(b), isFalse);
      expect(c.setFollower(a, false), isTrue);
      expect(c.groupForCard(a)!.roles, isEmpty);
    });

    test('source that was a follower becomes two-way if no other sender', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text);
      c.setFollower(a, true);
      c.linkCards(a, b, type: ContentType.text, targetFollows: true);
      expect(c.isFollower(b), isTrue);
      expect(c.isFollower(a), isFalse);

      // Stays a follower while another sender remains.
      final int d = c.openTool(UtilityCatalog.byId('list'));
      c.linkCards(b, d, type: ContentType.text);
      expect(c.setFollower(a, true), isTrue);
      c.linkCards(a, d, type: ContentType.text);
      expect(c.isFollower(a), isTrue);
    });

    test('invariant holds after unlink, close and merge', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      final int d = c.openTool(UtilityCatalog.byId('list'));
      c.linkCards(a, b, type: ContentType.text);
      c.linkCards(a, d, type: ContentType.text, targetFollows: true);
      c.setFollower(b, true);
      expect(c.isFollower(b) && c.isFollower(d), isTrue);
      c.unlinkCard(a); // remaining b, d all followers
      expect(c.isFollower(b), isFalse);
      expect(c.isFollower(d), isFalse);

      final CanvasController m = CanvasController();
      final int p = m.openTool(base64);
      final int q = m.openTool(json);
      final int r = m.openTool(UtilityCatalog.byId('list'));
      m.linkCards(p, q, type: ContentType.text);
      m.linkCards(p, r, type: ContentType.text, targetFollows: true);
      m.setFollower(q, true);
      m.close(p);
      expect(m.isFollower(q), isFalse);
      expect(m.isFollower(r), isFalse);

      final CanvasController g = CanvasController();
      final int a1 = g.openTool(base64);
      final int b1 = g.openTool(json);
      final int c1 = g.openTool(UtilityCatalog.byId('list'));
      final int d1 = g.openTool(UtilityCatalog.byId('color'));
      g.linkCards(a1, b1, type: ContentType.text, targetFollows: true);
      g.linkCards(c1, d1, type: ContentType.text, targetFollows: true);
      g.linkCards(a1, c1, type: ContentType.text);
      final LinkGroup merged = g.groupForCard(a1)!;
      expect(merged.members, <int>{a1, b1, c1, d1});
      expect(g.isFollower(b1), isTrue);
      expect(g.isFollower(d1), isTrue);
      expect(merged.members.any((int i) => merged.roleOf(i).sends), isTrue);
    });

    test('merge with a follower source keeps a sender', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text);
      c.setFollower(a, true);
      final int d = c.openTool(UtilityCatalog.byId('list'));
      final int e = c.openTool(UtilityCatalog.byId('color'));
      c.linkCards(d, e, type: ContentType.text, targetFollows: true);
      c.linkCards(a, d, type: ContentType.text);
      final LinkGroup g = c.groupForCard(a)!;
      expect(g.members.any((int i) => g.roleOf(i).sends), isTrue);
    });

    test('roles persist; send loads two-way, receive loads follower', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int b = c.openTool(json);
      c.linkCards(a, b, type: ContentType.text, targetFollows: true);
      final Map<String, dynamic> snap =
          jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      final Map<String, dynamic> group =
          (snap['groups'] as List<dynamic>).single as Map<String, dynamic>;
      expect(group['roles'], <String, dynamic>{'$b': 'receive'});
      final CanvasController r = CanvasController()..applyJson(snap);
      expect(r.isFollower(b), isTrue);
      expect(r.isFollower(a), isFalse);

      group['roles'] = <String, dynamic>{
        '$a': 'send',
        '999': 'receive',
        'x': 'receive',
        '$b': 'both',
      };
      final CanvasController j = CanvasController()..applyJson(snap);
      expect(j.groups.single.roles, isEmpty);

      group['roles'] = <String, dynamic>{'$a': 'receive', '$b': 'receive'};
      final CanvasController all = CanvasController()..applyJson(snap);
      final LinkGroup g = all.groups.single;
      expect(g.members.any((int i) => g.roleOf(i).sends), isTrue);

      group.remove('roles');
      expect(
        (CanvasController()..applyJson(snap)).groups.single.roles,
        isEmpty,
      );
      expect(CanvasController().toJson()['groups'], isEmpty);
    });
  });

  group('defaultLinkType', () {
    final CanvasController c = CanvasController();
    final UtilityDescriptor math = UtilityCatalog.byId('math');

    test('uses the target default type', () {
      expect(c.defaultLinkType(math, timestamp), ContentType.epoch);
      expect(c.defaultLinkType(timestamp, math), ContentType.number);
    });

    test('null without a shared type or live-link support', () {
      for (final UtilityDescriptor d in UtilityCatalog.all) {
        if (!d.inputSources.contains(UtilityInputSource.liveLink)) {
          expect(c.defaultLinkType(d, timestamp), isNull);
          expect(c.defaultLinkType(timestamp, d), isNull);
        }
      }
    });

    test('a group fixes the type when both tools support it', () {
      final LinkGroup num = LinkGroup(id: 1, type: ContentType.number);
      final LinkGroup txt = LinkGroup(id: 2, type: ContentType.text);
      expect(
        c.defaultLinkType(math, timestamp, sourceGroup: num),
        ContentType.number,
      );
      expect(
        c.defaultLinkType(math, timestamp, targetGroup: num),
        ContentType.number,
      );
      expect(
        c.defaultLinkType(math, timestamp, sourceGroup: num, targetGroup: txt),
        isNull,
      );
      expect(c.defaultLinkType(math, timestamp, sourceGroup: txt), isNull);
    });
  });
}
