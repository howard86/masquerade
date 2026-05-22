import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/jwt_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // Hand-built fixture: header = {"alg":"HS256"}, payload = {"sub":"123","exp":1700000000}
  const String token =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.sig';

  testWidgets('JWT — decodes header and payload fields', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('HS256'), findsWidgets);
    expect(find.textContaining('sub'), findsWidgets);
    expect(find.textContaining('123'), findsWidgets);
  });

  testWidgets('JWT — shows decode-only disclaimer', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('signature not verified'), findsOneWidget);
  });

  testWidgets('JWT — shows expired status for past exp', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    // exp is 2023-11-14, current time is 2026 → expired
    expect(find.textContaining('EXPIRED'), findsOneWidget);
  });

  testWidgets('JWT — shows error for invalid input', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, 'not.a.jwt!');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('Invalid'), findsWidgets);
  });

  testWidgets('JWT — pumps body at narrow width without overflow', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const JwtBody(initialInput: token), 380);
    await tester.pumpAndSettle(kDebouncePump);
    expect(tester.takeException(), isNull);
  });
}
