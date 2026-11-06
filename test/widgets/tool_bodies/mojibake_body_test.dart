import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Mojibake — repairs garbled text and shows summary', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Mojibake Repair');

    await tester.enterText(find.byType(EditableText).last, 'CafÃ©');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Codec: Windows-1252'), findsOneWidget);
    expect(find.text('Fixed: 1'), findsOneWidget);
    expect(find.text('Passes: 1'), findsOneWidget);
  });

  testWidgets('Mojibake — codec chip overrides auto', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Mojibake Repair');

    await tester.enterText(find.byType(EditableText).last, 'CafÃ©');
    await tester.pumpAndSettle(kDebouncePump);
    await tester.tap(find.text('Mac Roman'));
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('NO MOJIBAKE FOUND.'), findsOneWidget);
    expect(find.byType(MqMonoCell), findsNothing);

    await tester.tap(find.text('Latin-1'));
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Codec: Latin-1'), findsOneWidget);
  });

  testWidgets('Mojibake — clean text shows the no-op error', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'Mojibake Repair');

    await tester.enterText(find.byType(EditableText).last, 'café');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('NO MOJIBAKE FOUND.'), findsOneWidget);
  });
}
