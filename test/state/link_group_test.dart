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

  group('link capabilities and text shapes', () {
    final UtilityDescriptor hash = UtilityCatalog.byId('hash');
    final UtilityDescriptor gen = UtilityCatalog.byId('generator');
    final UtilityDescriptor color = UtilityCatalog.byId('color');
    final UtilityDescriptor list = UtilityCatalog.byId('list');
    final UtilityDescriptor regex = UtilityCatalog.byId('regex');

    test(
      'follow-only target is forced to follow; source-only never follows',
      () {
        final CanvasController c = CanvasController();
        final int a = c.openTool(base64);
        final int h = c.openTool(hash);
        c.linkCards(a, h, type: ContentType.text);
        expect(c.isFollower(h), isTrue);
        expect(c.isFollower(a), isFalse);
        expect(c.followFixed(h), isTrue);
        expect(c.followFixed(a), isFalse);
        expect(c.setFollower(h, false), isFalse);
        expect(c.isFollower(h), isTrue);

        final CanvasController d = CanvasController();
        final int x = d.openTool(base64);
        final int g = d.openTool(gen);
        d.linkCards(x, g, type: ContentType.text, targetFollows: true);
        expect(d.isFollower(g), isFalse);
        expect(d.canFollow(g), isFalse);
        expect(d.setFollower(g, true), isFalse);
        expect(d.followFixed(g), isTrue);
      },
    );

    test('follow-only source follows and the target seeds', () {
      final CanvasController c = CanvasController();
      final int h = c.openTool(hash);
      final int a = c.openTool(base64);
      c.linkCards(h, a, type: ContentType.text);
      expect(c.isFollower(h), isTrue);
      expect(c.isFollower(a), isFalse);
      expect(c.groupForCard(a)!.seedOwnerCardId, a);
    });

    test('two follow-only windows have no sender', () {
      final CanvasController c = CanvasController();
      final int h = c.openTool(hash);
      final int r = c.openTool(regex);
      expect(c.linkIssueFor(h, r, type: ContentType.text), LinkIssue.noSender);
      expect(c.linkCards(h, r, type: ContentType.text), isNull);
      expect(
        c.linkIssueFor(h, r, type: ContentType.text)!.message(ContentType.text),
        contains('must be able to send'),
      );
    });

    test('group dissolves when only follow-only members remain', () {
      final CanvasController c = CanvasController();
      final int a = c.openTool(base64);
      final int h = c.openTool(hash);
      final int r = c.openTool(regex);
      c.linkCards(a, h, type: ContentType.text);
      c.linkCards(a, r, type: ContentType.text);
      expect(c.groups.single.members, hasLength(3));
      c.unlinkCard(a);
      expect(c.groups, isEmpty);
    });

    test('source-only member may send into a follow-only one', () {
      final CanvasController c = CanvasController();
      final int g = c.openTool(gen);
      final int h = c.openTool(hash);
      expect(c.linkIssueFor(g, h, type: ContentType.text), isNull);
      expect(c.linkCards(g, h, type: ContentType.text), isNotNull);
    });

    test('Color text cannot feed JSON, in either direction', () {
      final CanvasController c = CanvasController();
      final int col = c.openTool(color);
      final int j = c.openTool(json);
      expect(
        c.linkIssueFor(col, j, type: ContentType.text),
        LinkIssue.shapeMismatch,
      );
      expect(
        c.linkIssueFor(j, col, type: ContentType.text),
        LinkIssue.shapeMismatch,
      );
      expect(c.linkCards(col, j, type: ContentType.text), isNull);
      expect(
        LinkIssue.shapeMismatch.message(ContentType.text),
        contains('different kinds of text'),
      );
    });

    test('plain tools still link with Color and JSON', () {
      final CanvasController c = CanvasController();
      final int l = c.openTool(list);
      final int col = c.openTool(color);
      final int b = c.openTool(base64);
      final int j = c.openTool(json);
      expect(c.linkIssueFor(l, col, type: ContentType.text), isNull);
      expect(c.linkIssueFor(b, j, type: ContentType.text), isNull);
    });

    test('merged group checks every sender -> receiver pair', () {
      final CanvasController c = CanvasController();
      final int col = c.openTool(color);
      final int l = c.openTool(list);
      final int j = c.openTool(json);
      final int b = c.openTool(base64);
      c.linkCards(col, l, type: ContentType.text);
      c.linkCards(j, b, type: ContentType.text);
      // Merging would let Color send into JSON.
      expect(
        c.linkIssueFor(l, b, type: ContentType.text),
        LinkIssue.shapeMismatch,
      );
      // A follow-only inspector joining the Color group never sends.
      final int h = c.openTool(hash);
      expect(c.linkIssueFor(l, h, type: ContentType.text), isNull);
      // Joining the JSON group from Color's side is also rejected.
      expect(
        c.linkIssueFor(col, j, type: ContentType.text),
        LinkIssue.shapeMismatch,
      );
    });

    test('a follower Color does not block a JSON sender it cannot read', () {
      final CanvasController c = CanvasController();
      final int j = c.openTool(json);
      final int l = c.openTool(list);
      c.linkCards(j, l, type: ContentType.text);
      final int col = c.openTool(color);
      // JSON sends json text; Color only reads color/plain.
      expect(
        c.linkIssueFor(l, col, type: ContentType.text),
        LinkIssue.shapeMismatch,
      );
    });

    test('non-member source reads as a new-window drop', () {
      final CanvasController c = CanvasController();
      final int jwt = c.openTool(UtilityCatalog.byId('jwt'));
      final int j = c.openTool(json);
      final LinkIssue? issue = c.linkIssueFor(jwt, j, type: ContentType.text);
      expect(issue, LinkIssue.sourceUnsupported);
      expect(
        issue!.message(ContentType.text),
        'Drop on the desktop to open it in a new window.',
      );
    });

    test('restore: capabilities and shapes are sanitized', () {
      Map<String, dynamic> card(int id, String tool) => <String, dynamic>{
        'id': id,
        'tool': tool,
        'x': 0,
        'y': 0,
        'w': 380,
      };
      final CanvasController c = CanvasController()
        ..applyJson(<String, dynamic>{
          'cards': <Map<String, dynamic>>[
            card(1, 'base64'),
            card(2, 'hash'),
            card(3, 'generator'),
            card(4, 'json'),
            card(5, 'color'),
          ],
          'groups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'type': 'text',
              'canonical': 'x',
              'members': <int>[1, 2, 3],
              'roles': <String, String>{'3': 'receive'},
            },
            <String, dynamic>{
              'id': 2,
              'type': 'text',
              'canonical': 'y',
              'members': <int>[4, 5],
            },
          ],
        });
      expect(c.groups, hasLength(1));
      final LinkGroup g = c.groups.single;
      expect(g.members, <int>{1, 2, 3});
      expect(c.isFollower(2), isTrue);
      expect(c.isFollower(3), isFalse);
      expect(c.isFollower(1), isFalse);
    });

    test('restore drops groups with no possible sender', () {
      Map<String, dynamic> card(int id, String tool) => <String, dynamic>{
        'id': id,
        'tool': tool,
        'x': 0,
        'y': 0,
        'w': 380,
      };
      final CanvasController c = CanvasController()
        ..applyJson(<String, dynamic>{
          'cards': <Map<String, dynamic>>[card(1, 'hash'), card(2, 'regex')],
          'groups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'type': 'text',
              'canonical': '',
              'members': <int>[1, 2],
            },
          ],
        });
      expect(c.groups, isEmpty);
    });
  });
}
