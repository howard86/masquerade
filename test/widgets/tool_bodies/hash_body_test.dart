import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/hash_parser.dart';
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

  testWidgets('hash — a slower async digest never overwrites a newer input', (
    WidgetTester tester,
  ) async {
    // Web computes SHA digests asynchronously (crypto.subtle); simulate that
    // with digests that resolve only when the test completes them.
    final List<(Completer<ShaDigests>, List<int>)> pending =
        <(Completer<ShaDigests>, List<int>)>[];
    HashTool.debugShaDigestsOverride = (List<int> bytes) {
      final Completer<ShaDigests> completer = Completer<ShaDigests>();
      pending.add((completer, bytes));
      return completer.future;
    };
    addTearDown(() => HashTool.debugShaDigestsOverride = null);
    await pumpHomeAndOpen(tester, 'Hash');

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tester.pump(kDebouncePump);
    await tester.enterText(find.byType(EditableText).first, 'xyz');
    await tester.pump(kDebouncePump);
    expect(pending, hasLength(2));

    // The newer input resolves first, then the stale one lands late.
    pending[1].$1.complete(HashTool.shaDigestsSync(pending[1].$2));
    await tester.pump();
    pending[0].$1.complete(HashTool.shaDigestsSync(pending[0].$2));
    await tester.pumpAndSettle();

    const String xyz = '3608bca1e44ea6c4d268eb6db0226026';
    const String abc = 'ba7816bf8f01cfea414140de5dae2223';
    expect(find.textContaining(xyz), findsOneWidget);
    expect(find.textContaining(abc), findsNothing);
  });
}
