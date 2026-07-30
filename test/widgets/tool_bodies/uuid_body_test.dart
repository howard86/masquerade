import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('uuid — pasting dashed UUID shows Version and Canonical rows', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'UUID');

    await tester.enterText(
      find.byType(EditableText).first,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Canonical'), findsOneWidget);
  });

  testWidgets('uuid — invalid input announces via a live-region error pill', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await pumpHomeAndOpen(tester, 'UUID');

    await tester.enterText(find.byType(EditableText).first, 'not-a-uuid');
    await tester.pumpAndSettle(kDebouncePump);

    final MqStatus status = tester.widget<MqStatus>(find.byType(MqStatus).last);
    expect(status.kind, MqStatusKind.danger);
    expect(status.label, contains('Not a valid UUID or ULID'));

    final SemanticsNode node = tester.getSemantics(find.byType(MqStatus).last);
    expect(node.label, status.label);
    expect(node.flagsCollection.isLiveRegion, isTrue);

    handle.dispose();
  });

  testWidgets('uuid — tapping Generate v4 populates a value', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'UUID');

    await tester.tap(find.text('Generate v4'));
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Version'), findsOneWidget);
  });

  testWidgets('uuid — Copy all writes every output cell to the clipboard', (
    WidgetTester tester,
  ) async {
    final List<String> clipboardWrites = <String>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final Map<dynamic, dynamic> args = call.arguments as Map;
        clipboardWrites.add(args['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpHomeAndOpen(tester, 'UUID');

    await tester.enterText(
      find.byType(EditableText).first,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('550e8400-e29b-41d4-a716-446655440000'));
    expect(written, contains('550e8400e29b41d4a716446655440000')); // No-dashes
    expect(
      written,
      contains('550E8400-E29B-41D4-A716-446655440000'),
    ); // Uppercase
    expect(written, contains('4')); // Version

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('uuid — Copy all is hidden when there is no valid output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'UUID');

    expect(find.text('Copy all'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'not a uuid');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);

    await tester.enterText(
      find.byType(EditableText).first,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);
  });
}
