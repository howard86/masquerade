import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/case_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('shows tokens and all twelve copyable conversions', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const CaseBody(initialInput: 'XMLHttpRequest'),
      340,
    );

    expect(find.text('xml · http · request'), findsOneWidget);
    expect(find.byType(MqMonoCell), findsNWidgets(13));
    expect(find.text('xmlHttpRequest'), findsOneWidget);
    expect(find.text('XML_HTTP_REQUEST'), findsOneWidget);
    expect(find.text('xml/http/request'), findsOneWidget);
  });

  testWidgets('copies every row value', (WidgetTester tester) async {
    String? copied;
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpHomeAndOpen(tester, 'Case');
    await tester.enterText(find.byType(EditableText).last, 'helloWorld');
    await tester.pumpAndSettle(kDebouncePump);
    const Map<String, String> expected = <String, String>{
      'camelCase': 'helloWorld',
      'PascalCase': 'HelloWorld',
      'snake_case': 'hello_world',
      'SCREAMING_SNAKE_CASE': 'HELLO_WORLD',
      'kebab-case': 'hello-world',
      'Train-Case': 'Hello-World',
      'Title Case': 'Hello World',
      'Sentence case': 'Hello world',
      'dot.case': 'hello.world',
      'path/case': 'hello/world',
      'lower case': 'hello world',
      'UPPER CASE': 'HELLO WORLD',
    };
    for (final MapEntry<String, String> row in expected.entries) {
      final Finder cell = find.byWidgetPredicate(
        (Widget widget) => widget is MqMonoCell && widget.label == row.key,
      );
      final Finder copyTarget = find.descendant(
        of: cell,
        matching: find.byKey(const ValueKey<String>('mqMonoCellCopyTarget')),
      );
      final GestureDetector detector = tester.widget<GestureDetector>(
        find.ancestor(of: copyTarget, matching: find.byType(GestureDetector)),
      );
      detector.onTap!();
      expect(copied, row.value, reason: row.key);
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('stays overflow-free at 340 px and 2x text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpBodyAtWidth(
      tester,
      const CaseBody(initialInput: 'user_id_42'),
      340,
    );

    expect(find.text('user · id · 42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces invalid-input errors', (WidgetTester tester) async {
    await pumpBodyAtWidth(tester, const CaseBody(initialInput: '!!!'), 340);
    expect(find.textContaining('identifier separators'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('surfaces the input bound without conversion rows', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, CaseBody(initialInput: 'a' * 10001), 340);
    expect(
      tester.widget<MqInput>(find.byType(MqInput)).error,
      'Input is limited to 10000 characters.',
    );
    expect(find.byType(MqMonoCell), findsOneWidget);
  });
}
