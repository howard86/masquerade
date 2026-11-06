import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/bps_body.dart';
import 'package:masquerade/widgets/tool_bodies/generator_body.dart';
import 'package:masquerade/widgets/tool_bodies/ip_body.dart';
import 'package:masquerade/widgets/tool_bodies/url_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

class _Harness {
  _Harness(this.type, {this.seed = false});
  final ContentType type;
  final bool seed;
  final ValueNotifier<String> inbound = ValueNotifier<String>('');
  final List<String> emitted = <String>[];

  LinkChannel get channel => LinkChannel(
    canonicalType: type,
    inbound: inbound,
    seedOnAttach: seed,
    onEmit: emitted.add,
  );
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  await pumpBodyAtWidth(tester, body, 480);
  await tester.pumpAndSettle(kDebouncePump);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText).first, text);
  await tester.pumpAndSettle(kDebouncePump);
}

String _input(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('bps emits the decimal fraction and projects inbound', (
    WidgetTester tester,
  ) async {
    final _Harness h = _Harness(ContentType.number);
    await _pump(tester, BpsBody(link: h.channel));
    await _type(tester, '25 bps');
    expect(h.emitted.last, '0.0025');

    await _type(tester, '1.5%');
    expect(h.emitted.last, '0.015');

    h.inbound.value = '2';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), '20000 bps');
    expect(h.emitted.last, '2');
  });

  testWidgets('ip emits integer for one address and projects inbound', (
    WidgetTester tester,
  ) async {
    final _Harness h = _Harness(ContentType.number);
    await _pump(tester, IpBody(link: h.channel));
    await _type(tester, '192.168.1.1');
    expect(h.emitted.last, '3232235777');

    await _type(tester, '192.168.1.0/24');
    expect(h.emitted.last, '');

    h.inbound.value = '3232235777';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), '192.168.1.1');

    h.inbound.value = '42540766411282592856903984951653826561';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), '2001:db8::1');
    expect(h.emitted.last, '42540766411282592856903984951653826561');

    h.inbound.value = '${BigInt.one << 128}';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), '2001:db8::1');
  });

  testWidgets('generator emits on generate and ignores inbound', (
    WidgetTester tester,
  ) async {
    final _Harness h = _Harness(ContentType.text, seed: true);
    await _pump(tester, GeneratorBody(link: h.channel));
    expect(h.emitted, isNotEmpty);
    final String first = h.emitted.last;
    expect(first, isNotEmpty);

    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();
    expect(h.emitted.last, isNot(first));
    final int count = h.emitted.length;

    h.inbound.value = 'from-elsewhere';
    await tester.pumpAndSettle(kDebouncePump);
    expect(h.emitted.length, count);
    expect(find.textContaining('from-elsewhere'), findsNothing);
  });

  testWidgets('url round-trips encode and inbound', (
    WidgetTester tester,
  ) async {
    final _Harness h = _Harness(ContentType.text);
    await _pump(tester, UrlBody(link: h.channel));
    await _type(tester, 'a b&c');
    expect(h.emitted.last, 'a b&c');

    h.inbound.value = 'hello world';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), 'hello world');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();
    h.inbound.value = 'x y/z';
    await tester.pumpAndSettle(kDebouncePump);
    expect(_input(tester), Uri.encodeComponent('x y/z'));
    expect(h.emitted.last, 'x y/z');
  });
}
