import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/case_body.dart';
import 'package:masquerade/widgets/tool_bodies/hash_body.dart';
import 'package:masquerade/widgets/tool_bodies/markdown_body.dart';
import 'package:masquerade/widgets/tool_bodies/mojibake_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final Map<String, Widget Function(LinkChannel)> bodies =
      <String, Widget Function(LinkChannel)>{
        'Hash': (LinkChannel l) => HashBody(link: l),
        'Case': (LinkChannel l) => CaseBody(link: l),
        'Mojibake': (LinkChannel l) => MojibakeBody(link: l),
        'Markdown': (LinkChannel l) => MarkdownBody(link: l),
      };

  for (final MapEntry<String, Widget Function(LinkChannel)> e
      in bodies.entries) {
    testWidgets('${e.key} follows the group text and never sends', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<String> inbound = ValueNotifier<String>('');
      final List<String> emitted = <String>[];
      final LinkChannel link = LinkChannel(
        canonicalType: ContentType.text,
        inbound: inbound,
        role: () => LinkRole.receive,
        seedOnAttach: false,
        onEmit: emitted.add,
      );
      await pumpBodyAtWidth(tester, e.value(link), 600);

      inbound.value = 'hello world';
      await tester.pump();
      await tester.pump(kDebouncePump);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is EditableText && w.controller.text == 'hello world',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(EditableText).first, 'local edit');
      await tester.pumpAndSettle(kDebouncePump);
      expect(emitted.where((String v) => v != 'hello world'), isEmpty);
    });
  }
}
