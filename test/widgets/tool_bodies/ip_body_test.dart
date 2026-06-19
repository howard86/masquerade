import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('ip — CIDR input shows subnet rows', (WidgetTester tester) async {
    await pumpHomeAndOpen(tester, 'IP / CIDR');

    await tester.enterText(find.byType(EditableText).first, '192.168.1.0/24');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Broadcast'), findsOneWidget);
    expect(find.text('Host count'), findsOneWidget);
    expect(find.text('Netmask'), findsOneWidget);
  });

  testWidgets('ip — bare address shows only address and scope chips', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'IP / CIDR');

    await tester.enterText(find.byType(EditableText).first, '10.0.0.1');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Canonical'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    // No subnet rows for bare address
    expect(find.text('Network'), findsNothing);
    expect(find.text('Broadcast'), findsNothing);
  });

  testWidgets('ip — Copy all writes every output cell to the clipboard', (
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

    await pumpHomeAndOpen(tester, 'IP / CIDR');

    await tester.enterText(find.byType(EditableText).first, '192.168.1.0/24');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('192.168.1.0')); // Canonical / Network
    expect(written, contains('IPv4')); // Family
    expect(written, contains('/24')); // Prefix
    expect(written, contains('192.168.1.255')); // Broadcast
    expect(written, contains('192.168.1.1')); // First host
    expect(written, contains('192.168.1.254')); // Last host
    expect(written, contains('256')); // Host count
    expect(written, contains('255.255.255.0')); // Netmask

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('ip — Copy all is hidden when there is no valid output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'IP / CIDR');

    // Empty input → nothing parsed → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    // An invalid address keeps it hidden.
    await tester.enterText(find.byType(EditableText).first, 'not an ip');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);

    // A valid address surfaces it.
    await tester.enterText(find.byType(EditableText).first, '10.0.0.1');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);
  });
}
