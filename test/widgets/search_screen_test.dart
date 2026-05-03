import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openSearchTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // The Search tab is the second tab (index 1) of RootTabScaffold; the
    // Cupertino tab bar item label is "Search".
    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();
  }

  testWidgets('Search lists all tools when query is empty', (
    WidgetTester tester,
  ) async {
    await openSearchTab(tester);
    expect(find.text('Base64'), findsWidgets);
    expect(find.text('JSON'), findsWidgets);
    expect(find.text('Color'), findsWidgets);
  });

  testWidgets(
    'Tapping a search result expands inline; tapping another collapses the first',
    (WidgetTester tester) async {
      await openSearchTab(tester);

      // No card expanded → no body content (e.g. JSON's segmented control).
      expect(find.text('Pretty'), findsNothing);

      await tester.tap(find.text('JSON').first);
      await tester.pumpAndSettle();
      expect(find.text('Pretty'), findsOneWidget);
      // Inline expansion — no detail screen pushed onto the search nav stack.
      expect(find.byType(CupertinoNavigationBar), findsNothing);

      await tester.tap(find.text('Base64').first);
      await tester.pumpAndSettle();
      expect(find.text('Pretty'), findsNothing);
      expect(find.text('Encode'), findsOneWidget);
    },
  );
}
