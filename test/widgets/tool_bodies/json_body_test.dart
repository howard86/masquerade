import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('JSON — default Pretty target formats minified input', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('PRETTY'), findsOneWidget);
    expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
  });

  testWidgets('JSON — Tree target renders key path lines', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);

    // Open the Target dropdown and pick Tree.
    await tester.tap(find.text('Pretty JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tree').last);
    await tester.pumpAndSettle();

    expect(find.text('TREE'), findsOneWidget);
    expect(find.text('{\n  a: 1\n}'), findsOneWidget);
  });

  testWidgets('JSON — invalid input shows error badge with line/col', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '{');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('ERROR · LINE 1 COL'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
  });

  testWidgets('YAML input auto-detects and converts to JSON', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, 'a: 1\nb: hello');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Detected YAML'), findsOneWidget);
    expect(find.text('PRETTY'), findsOneWidget);
    expect(find.text('{\n  "a": 1,\n  "b": "hello"\n}'), findsOneWidget);
  });

  testWidgets('TOML input auto-detects and converts to JSON', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(
      find.byType(EditableText).last,
      '[server]\nport = 8080',
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Detected TOML'), findsOneWidget);
    expect(
      find.text('{\n  "server": {\n    "port": 8080\n  }\n}'),
      findsOneWidget,
    );
  });

  testWidgets('multi-doc YAML shows a 1-of-N chip', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, 'a: 1\n---\nb: 2');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Multi-doc · 1 of 2'), findsOneWidget);
    // Only first doc rendered.
    expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
  });

  testWidgets('swap button moves output to input and exchanges selectors', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '{"a":1}');
    await tester.pumpAndSettle(kDebouncePump);

    // Switch Target to YAML.
    await tester.tap(find.text('Pretty JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YAML').last);
    await tester.pumpAndSettle();

    // YAML output visible.
    expect(find.text('YAML'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Swap source and target'));
    await tester.pumpAndSettle(kDebouncePump);

    // Input now holds YAML; Target now shows Pretty JSON.
    expect(find.text('Pretty JSON'), findsOneWidget);
    expect(find.text('YAML'), findsWidgets); // source dropdown shows YAML
    expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
  });

  testWidgets('list-root input hides the TOML target option', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    await tester.enterText(find.byType(EditableText).last, '[1, 2, 3]');
    await tester.pumpAndSettle(kDebouncePump);

    // Open the Target dropdown.
    await tester.tap(find.text('Pretty JSON'));
    await tester.pumpAndSettle();

    // A bare array has no TOML table representation, so the TOML target is
    // withheld; YAML and the rest stay available.
    expect(find.text('YAML'), findsOneWidget);
    expect(find.text('TOML'), findsNothing);
  });

  testWidgets('editing a Map root to a list resets an active TOML target', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JSON / YAML / TOML');

    // A Map root lets TOML be selected as the target.
    await tester.enterText(find.byType(EditableText).last, '{"a": 1}');
    await tester.pumpAndSettle(kDebouncePump);
    await tester.tap(find.text('Pretty JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TOML').last);
    await tester.pumpAndSettle();
    expect(find.text('TOML'), findsWidgets); // target now TOML

    // Re-parsing to a bare array (no table root) must drop back to Pretty JSON
    // rather than leave a stale, unrenderable TOML selection.
    await tester.enterText(find.byType(EditableText).last, '[1, 2, 3]');
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('Pretty JSON'), findsOneWidget);
    expect(find.text('[\n  1,\n  2,\n  3\n]'), findsOneWidget);
  });
}
