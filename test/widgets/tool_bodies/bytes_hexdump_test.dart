import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/bytes_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> decode(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Bytes — hexdump + encoding selector hidden at phone width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const BytesBody(), 340);
    await decode(tester, '72 101 108 108 111'); // "Hello"

    // Mobile parity: UTF-8 decode only, no hexdump, no encoding picker.
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('HEXDUMP'), findsNothing);
    expect(find.text('Latin-1'), findsNothing);
    expect(find.text('UTF-16LE'), findsNothing);
  });

  testWidgets('Bytes — hexdump + encoding selector visible at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const BytesBody(), 640);
    await decode(tester, '72 101 108 108 111'); // "Hello"

    expect(find.text('HEXDUMP'), findsOneWidget);
    expect(find.text('Latin-1'), findsOneWidget);
    expect(find.text('UTF-16LE'), findsOneWidget);
    // Offset/hex/ASCII row for "Hello": 0x48 65 6c 6c 6f -> |Hello|.
    expect(find.textContaining('|Hello|'), findsOneWidget);
  });

  testWidgets('Bytes — Latin-1 decodes a high byte that UTF-8 rejects', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const BytesBody(), 640);
    await decode(tester, '200'); // 0xC8 — invalid lone UTF-8 byte

    // UTF-8 path errors; switching to Latin-1 yields È (U+00C8).
    expect(find.textContaining('Invalid UTF-8'), findsOneWidget);
    await tester.tap(find.text('Latin-1'));
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('È'), findsOneWidget);
  });
}
