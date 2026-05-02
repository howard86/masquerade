import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/widgets/iphone_frame.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openTimestampScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final Finder timestampTile = find.text('Timestamp');
    expect(timestampTile, findsWidgets);
    await tester.tap(timestampTile.first);
    await tester.pumpAndSettle();
  }

  testWidgets('Home → Timestamp utility flow', (WidgetTester tester) async {
    await openTimestampScreen(tester);

    final Finder inputField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder ==
              'Enter timestamp (Unix s/ms/µs/ns, ISO 8601, or keyword)',
    );
    expect(inputField, findsOneWidget);

    await tester.enterText(inputField, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(find.text('UTC'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Unix seconds'), findsOneWidget);
    expect(find.text('Unix ms'), findsOneWidget);
    expect(find.text('ISO 8601'), findsOneWidget);
    expect(find.text('Relative'), findsOneWidget);

    await tester.enterText(inputField, '1700000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('UTC'), findsOneWidget);

    await tester.enterText(inputField, 'not a timestamp');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.textContaining('Invalid input format'), findsOneWidget);

    await tester.enterText(inputField, '');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('UTC'), findsNothing);
    expect(find.textContaining('Invalid input format'), findsNothing);
  });

  testWidgets('Timestamp copy notification', (WidgetTester tester) async {
    await openTimestampScreen(tester);

    final Finder inputField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder ==
              'Enter timestamp (Unix s/ms/µs/ns, ISO 8601, or keyword)',
    );
    await tester.enterText(inputField, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    final Finder copyButton = find.bySemanticsLabel(RegExp(r'^Copy '));
    expect(copyButton, findsWidgets);
    await tester.ensureVisible(copyButton.first);
    await tester.pumpAndSettle();
    await tester.tap(copyButton.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Color tab opens without crash and parses input', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Color'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Color').first);
    await tester.pumpAndSettle();

    final Finder field = find.byWidgetPredicate(
      (Widget w) =>
          w is CupertinoTextField &&
          w.placeholder == '#00B8C4, rgb(0,184,196), hsl(184,100%,38%)',
    );
    expect(
      field,
      findsOneWidget,
      reason: 'Color screen input should be present',
    );

    await tester.enterText(field, '#FF0000');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(find.text('#FF0000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone frame wraps every screen, including pushed routes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byType(IphoneFrame),
      findsOneWidget,
      reason: 'Home should render inside the iPhone frame on large screens',
    );

    await tester.tap(find.text('Timestamp').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(IphoneFrame),
      findsOneWidget,
      reason: 'Pushed detail screen must stay inside the iPhone frame',
    );
  });
}
