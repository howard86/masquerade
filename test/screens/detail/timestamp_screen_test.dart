import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'Timestamp ambiguity badge shows for values in seconds/ms overlap range',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Open Timestamp detail screen via the hero "Open in" chip path —
      // typing 1700000000 surfaces it both as a chip and the grid tile.
      // Tap the grid tile (last Timestamp text on Home).
      final Finder timestampTile = find.text('Timestamp');
      expect(timestampTile, findsWidgets);
      await tester.tap(timestampTile.last);
      await tester.pumpAndSettle();

      // Enter a 10-digit unix-seconds value that also parses as ms — value
      // sits in the ambiguous range (1e9, 1e12).
      final Finder input = find.byType(EditableText);
      await tester.enterText(input, '1700000000');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('AMBIGUOUS'), findsOneWidget);
    },
  );

  testWidgets('Timestamp ambiguity badge hidden for unambiguous ms value', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timestamp').last);
    await tester.pumpAndSettle();

    // 13-digit ms value — above 1e12, so unambiguous.
    final Finder input = find.byType(EditableText);
    await tester.enterText(input, '1700000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('AMBIGUOUS'), findsNothing);
  });
}
