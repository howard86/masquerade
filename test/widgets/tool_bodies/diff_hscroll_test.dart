import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Diff — a long line scrolls horizontally without overflow', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Diff');

    final String longLine = 'x' * 400; // far wider than the viewport
    await tester.enterText(find.byType(EditableText).first, longLine);
    await tester.enterText(find.byType(EditableText).last, '${longLine}y');
    await tester.pumpAndSettle(kDebouncePump);

    // The diff view renders inside a horizontal scroll view so each line stays
    // single-line and the gutters stay column-aligned.
    final Finder hScroll = find.byWidgetPredicate(
      (Widget w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(hScroll, findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
