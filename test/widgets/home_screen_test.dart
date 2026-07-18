import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<Finder> pumpHero(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();
    final Finder input = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
    );
    expect(input, findsOneWidget);
    return input;
  }

  Finder semantics(String label) => find.byWidgetPredicate(
    (Widget widget) => widget is Semantics && widget.properties.label == label,
  );

  testWidgets('empty capture offers explicit paste and QR scan controls', (
    WidgetTester tester,
  ) async {
    await pumpHero(tester);

    expect(semantics('Empty Workbench'), findsOneWidget);
    expect(find.bySemanticsLabel('Paste'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan QR'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('captured content reveals Paste and Clear then clears state', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '#ff5733');
    await tester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Artifact detected'), findsOneWidget);
    expect(semantics('Open Color'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(semantics('Empty Workbench'), findsOneWidget);
    expect(find.text('TOOL SUGGESTIONS'), findsNothing);
  });

  testWidgets('artifact detection can suggest more than one existing tool', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '1700000000');
    await tester.pump();

    expect(semantics('Open Number Base'), findsOneWidget);
    expect(semantics('Open Timestamp'), findsOneWidget);
  });

  testWidgets('tapping a suggestion pushes a route seeded with capture', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '{"hello":"world"}');
    await tester.pump();

    await tester.tap(find.text('JSON / YAML / TOML'));
    await tester.pumpAndSettle();

    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'json');
    expect(route.seed, '{"hello":"world"}');
  });
}
