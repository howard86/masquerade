import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/color_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// The palette strip is a Wrap of plain swatch Containers — it carries no text,
/// so we count the GestureDetector swatches against a tappable-swatch marker.
Finder _swatches() => find.descendant(
  of: find.byType(Wrap),
  matching: find.byType(GestureDetector),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(EditableText).last, input);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Color palette — strip absent at phone width (mobile parity)', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const ColorBody(), 340);

    await enter(tester, '#FF0000');
    await enter(tester, '#00FF00');

    // No palette Wrap is built at compact width.
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('Color palette — strip present at wide width with swatches', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const ColorBody(), 640);

    await enter(tester, '#FF0000');
    await enter(tester, '#00FF00');

    // Two distinct colors entered this session -> two sticky swatches.
    expect(_swatches(), findsNWidgets(2));
  });

  testWidgets('Color palette — tapping a swatch reloads that color', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const ColorBody(), 640);

    await enter(tester, '#FF0000');
    await enter(tester, '#00FF00');
    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('#00FF00'),
      ),
      findsOneWidget,
    );

    // Most-recent-first: the second swatch is the older #FF0000.
    await tester.tap(_swatches().last);
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('#FF0000'),
      ),
      findsOneWidget,
    );
  });
}
