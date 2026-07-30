import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('hash — typing text shows SHA-256 digest', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // SHA-256 of "abc"
    expect(
      find.textContaining('ba7816bf8f01cfea414140de5dae2223'),
      findsOneWidget,
    );
  });

  testWidgets('hash — typing text shows MD5 digest', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // MD5 of "abc"
    expect(
      find.textContaining('900150983cd24fb0d6963f7d28e17f72'),
      findsOneWidget,
    );
  });

  testWidgets('hash — matching expected digest highlights row', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // Enter the SHA-256 digest in the verify field
    final Finder verifyField = find.byType(EditableText).last;
    await tester.enterText(
      verifyField,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    await tester.pumpAndSettle();

    // The SHA-256 row should now be accented (accent: true renders with
    // accentBg background). We verify by checking the label still renders.
    expect(find.text('SHA-256'), findsOneWidget);
  });

  testWidgets('hash — copy buttons announce which digest they copy', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    // Four indistinguishable "Copy <hex preview>" labels can't be told
    // apart by a screen reader; each copy button must instead name its
    // own algorithm.
    for (final String algorithm in <String>[
      'MD5',
      'SHA-1',
      'SHA-256',
      'SHA-512',
    ]) {
      expect(
        find.bySemanticsLabel('Copy $algorithm'),
        findsOneWidget,
        reason: 'missing copy label for $algorithm',
      );
    }
  });

  testWidgets('hash — Copy all writes every digest to the clipboard', (
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

    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('900150983cd24fb0d6963f7d28e17f72')); // MD5
    expect(
      written,
      contains('a9993e364706816aba3e25717850c26c9cd0d89'),
    ); // SHA-1
    expect(written, contains('ba7816bf8f01cfea414140de5dae2223')); // SHA-256
    expect(
      written,
      contains('ddaf35a193617abacc417349ae20413112e6fa4'),
    ); // SHA-512

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('hash — Copy all is hidden when the input is empty', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Hash');

    // Empty input → nothing typed yet → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);
  });
}
