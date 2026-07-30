import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Bytes — decode plain space-separated integers to UTF-8 + hex', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(
      find.byType(EditableText).last,
      '72 101 108 108 111',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('48 65 6c 6c 6f'), findsOneWidget);
  });

  testWidgets('Bytes — decode bracketed comma list', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText).last, '[72, 105]');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Hi'), findsOneWidget);
    expect(find.text('48 69'), findsOneWidget);
  });

  testWidgets('Bytes — encode shows space, brackets, and hex simultaneously', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.tap(find.text('Encode'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).last, 'Hi');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('72 105'), findsOneWidget);
    expect(find.text('[72, 105]'), findsOneWidget);
    expect(find.text('48 69'), findsOneWidget);
  });

  testWidgets('Bytes — out-of-range integer surfaces parser error via '
      'MqInput.error, not an Error MqMonoCell', (WidgetTester tester) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText).last, '300 1 2');
    await tester.pumpAndSettle(kDebouncePump);

    // The precise parser message is preserved and rendered inside the MqInput's
    // error slot (the standard error surface), not a generic string.
    final Finder error = find.textContaining('out of range');
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: find.byType(MqInput), matching: error),
      findsOneWidget,
    );

    // It is no longer shown in an MqMonoCell labelled 'Error'.
    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('Error'),
      ),
      findsNothing,
    );
  });

  testWidgets('Bytes — invalid UTF-8 still renders hex preview', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Bytes');

    // 0xC8 0xC8 are valid byte values but not a valid UTF-8 sequence.
    await tester.enterText(find.byType(EditableText).last, '200 200');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Invalid UTF-8'), findsOneWidget);
    expect(find.text('c8 c8'), findsOneWidget);
  });

  testWidgets('Bytes — decoded credentials protect every reversible output', (
    WidgetTester tester,
  ) async {
    const String credential = '{"password":"raw-credential-fixture"}';
    final String encoded = credential.codeUnits.join(' ');
    final String hex = credential.codeUnits
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    String? clipboard;
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<dynamic, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpHomeAndOpen(tester, 'Bytes');

    await tester.enterText(find.byType(EditableText).last, encoded);
    await tester.pumpAndSettle(kDebouncePump);

    final Finder textCell = find.byWidgetPredicate(
      (Widget widget) =>
          widget is MqMonoCell && widget.label.startsWith('Text'),
    );
    final Finder hexCell = find.byWidgetPredicate(
      (Widget widget) => widget is MqMonoCell && widget.label == 'Hex',
    );
    expect(
      find.descendant(
        of: textCell,
        matching: find.bySemanticsLabel('Copy Text (UTF-8)'),
      ),
      findsOneWidget,
    );
    final Finder hexCopy = find.descendant(
      of: hexCell,
      matching: find.bySemanticsLabel('Copy Hex'),
    );
    expect(hexCopy, findsOneWidget);

    await tester.tap(hexCopy);
    await tester.pump();

    expect(clipboard, hex);
    expect(find.text(hex), findsOneWidget);
    expect(find.text('••••'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
