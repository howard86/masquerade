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
}
