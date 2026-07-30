import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/mq/mq_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Base64 — encode mode produces standard base64 output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.enterText(find.byType(EditableText).last, 'hello');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('aGVsbG8='), findsOneWidget);
  });

  testWidgets('Base64 — decode mode round-trips back to plain text', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).last, 'aGVsbG8=');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('Base64 — URL-safe chip flips +/ to -_', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    // ">>>" → bytes 0x3E×3 → standard "Pj4+", URL-safe "Pj4-".
    await tester.enterText(find.byType(EditableText).last, '>>>');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Pj4+'), findsOneWidget);

    await tester.tap(find.text('URL-safe'));
    await tester.pumpAndSettle();
    expect(find.text('Pj4-'), findsOneWidget);
  });

  testWidgets('Base64 — Strip-padding chip drops trailing =', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    // "h" → bytes [0x68] → "aA==", stripped "aA".
    await tester.enterText(find.byType(EditableText).last, 'h');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('aA=='), findsOneWidget);

    await tester.tap(find.text('Strip padding'));
    await tester.pumpAndSettle();
    expect(find.text('aA'), findsOneWidget);
  });

  testWidgets(
    'Base64 — invalid decode input announces via a live-region error pill',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpHomeAndOpen(tester, 'Base64');

      await tester.tap(find.text('Decode'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).last, 'not@valid');
      await tester.pumpAndSettle(kDebouncePump);

      final MqStatus status = tester.widget<MqStatus>(find.byType(MqStatus));
      expect(status.kind, MqStatusKind.danger);
      expect(status.label, contains('Invalid base64'));

      final SemanticsNode node = tester.getSemantics(find.byType(MqStatus));
      expect(node.label, status.label);
      expect(node.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    },
  );

  testWidgets('Base64 — transformed credential output keeps protection', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');

    await tester.enterText(
      find.byType(EditableText).last,
      '{"password":"raw-credential-fixture"}',
    );
    await tester.pumpAndSettle(kDebouncePump);

    final MqMonoCell output = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .firstWhere((MqMonoCell cell) => cell.label == 'Base64');
    expect(output.sensitive, isTrue);
    expect(find.bySemanticsLabel('Copy Base64'), findsOneWidget);
  });

  testWidgets('Base64 — decoded credentials keep protection', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Base64');
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).last,
      'eyJwYXNzd29yZCI6InJhdy1jcmVkZW50aWFsLWZpeHR1cmUifQ==',
    );
    await tester.pumpAndSettle(kDebouncePump);

    final MqMonoCell output = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .firstWhere((MqMonoCell cell) => cell.label == 'Plain text');
    expect(output.sensitive, isTrue);
    expect(find.bySemanticsLabel('Copy Plain text'), findsOneWidget);
  });
}
