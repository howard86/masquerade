import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/utils/bps_parser.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('bps — explicit "bps" suffix detects BPS form', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText).last, '100bps');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.bps.name.toUpperCase()), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('1.0000%'), findsOneWidget);
    expect(find.text('0.010000'), findsOneWidget);
  });

  testWidgets('bps — "%" suffix detects PERCENT form and back-computes bps', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText).last, '0.5%');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.percent.name.toUpperCase()), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('0.5000%'), findsOneWidget);
    expect(find.text('0.005000'), findsOneWidget);
  });

  testWidgets('bps — bare small decimal detects DECIMAL form', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText).last, '0.025');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text(BpsForm.decimal.name.toUpperCase()), findsOneWidget);
    expect(find.text('250.00'), findsOneWidget);
    expect(find.text('2.5000%'), findsOneWidget);
    expect(find.text('0.025000'), findsOneWidget);
  });

  testWidgets('bps — non-numeric input surfaces error cell', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText).last, 'not a rate');
    await tester.pumpAndSettle(kDebouncePump);

    expect(
      find.textContaining('Could not parse as bps, % or decimal'),
      findsOneWidget,
    );
  });

  testWidgets('bps — Copy all writes every output value to the clipboard', (
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

    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    await tester.enterText(find.byType(EditableText).last, '100bps');
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    final String written = clipboardWrites.single;
    expect(written, contains('100.00')); // Basis points
    expect(written, contains('1.0000%')); // Percent
    expect(written, contains('0.010000')); // Decimal

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('bps — Copy all is hidden when there is no valid output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'bps · % · decimal');

    // Empty input → nothing parsed → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    // Invalid input keeps it hidden.
    await tester.enterText(find.byType(EditableText).last, 'not a rate');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);

    // A valid value surfaces it.
    await tester.enterText(find.byType(EditableText).last, '100bps');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);
  });
}
